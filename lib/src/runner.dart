import 'dart:async';
import 'dart:io';

import 'cli_args.dart';
import 'copy_pool.dart';
import 'fs_utils.dart';
import 'mover.dart';
import 'progress.dart';
import 'safety.dart';
import 'scan.dart';

enum Operation { copy, move }

Future<int> runTool(Operation operation, List<String> args) async {
  final bool isMove = operation == Operation.move;
  final String toolName = isMove ? 'pm' : 'pc';
  int code;
  try {
    final CliArgs cliArgs = parseCliArgs(
      args,
      toolName,
      isMove ? 'Move' : 'Copy',
    );
    code = await _execute(operation, cliArgs);
  } on CliExit catch (e) {
    (e.toStderr ? stderr : stdout).write(e.output);
    code = e.code;
  } on SafetyException catch (e) {
    stderr.writeln('$toolName: ${e.message}');
    code = 1;
  } on FileSystemException catch (e) {
    stderr.writeln('$toolName: ${describeError(e)}');
    code = 1;
  }
  await _flushOutput();
  return code;
}

Future<int> _execute(Operation operation, CliArgs cliArgs) async {
  final bool isMove = operation == Operation.move;
  final bool followSourceLink = !isMove;

  final String destination = resolveDestination(
    cliArgs.sourcePath,
    cliArgs.destinationPath,
    noTargetDirectory: cliArgs.noTargetDirectory,
  );
  runSafetyChecks(
    cliArgs.sourcePath,
    destination,
    force: cliArgs.force,
    followSourceLink: followSourceLink,
  );

  if (isMove && tryRename(cliArgs.sourcePath, destination)) {
    stdout.writeln('Moved to $destination (renamed instantly).');
    return 0;
  }

  final ScanResult scanResult = scan(
    cliArgs.sourcePath,
    destination,
    followSourceLink: followSourceLink,
  );

  if (isMove && scanResult.issues.isNotEmpty) {
    stderr.writeln('Refusing to move, some entries could not be read:');
    for (final ScanIssue issue in scanResult.issues) {
      stderr.writeln('  ${issue.path}: ${issue.message}');
    }
    return 1;
  }

  if (scanResult.tasks.isEmpty && scanResult.directories.isEmpty) {
    stdout.writeln('Nothing to ${isMove ? 'move' : 'copy'}.');
    return 0;
  }

  final ProgressBar progress = ProgressBar(
    totalBytes: scanResult.totalBytes,
    totalFiles: scanResult.tasks.length,
  );

  final StreamSubscription<ProcessSignal> interrupt = ProcessSignal.sigint
      .watch()
      .listen((ProcessSignal signal) {
        cancelActiveCopy();
        progress.interrupt();
        stderr.writeln('Interrupted.');
        exit(130);
      });

  final List<CopyFailure> failures = <CopyFailure>[
    for (final ScanIssue issue in scanResult.issues)
      CopyFailure(issue.path, issue.message),
  ];
  try {
    if (isMove) {
      failures.addAll(
        await moveViaCopy(
          scanResult: scanResult,
          progress: progress,
          concurrency: cliArgs.jobs,
        ),
      );
    } else {
      failures.addAll(
        await copyScanResult(
          scanResult: scanResult,
          progress: progress,
          concurrency: cliArgs.jobs,
        ),
      );
    }
  } finally {
    await interrupt.cancel();
  }

  progress.done();

  for (final String path in scanResult.skipped) {
    stdout.writeln('Skipped (not a regular file): $path');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Completed with ${failures.length} error(s):');
    for (final CopyFailure failure in failures) {
      stderr.writeln('  ${failure.sourcePath}: ${failure.message}');
    }
    return 1;
  }

  final int files = scanResult.tasks.length;
  final String what = files == 0
      ? '${scanResult.directories.length} folder(s)'
      : '$files file(s)';
  stdout.writeln(
    '${isMove ? 'Moved' : 'Copied'} $what to $destination '
    '(${progress.stats()}).',
  );
  return 0;
}

Future<void> _flushOutput() async {
  try {
    await stdout.flush();
    await stderr.flush();
  } on Object catch (_) {
    return;
  }
}

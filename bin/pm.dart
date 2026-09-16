import 'dart:io';

import 'package:pscm/src/cli_args.dart';
import 'package:pscm/src/copy_pool.dart';
import 'package:pscm/src/mover.dart';
import 'package:pscm/src/progress.dart';
import 'package:pscm/src/safety.dart';
import 'package:pscm/src/scan.dart';

Future<void> main(List<String> args) async {
  final CliArgs cliArgs;
  try {
    cliArgs = parseCliArgs(args, 'pm', 'Move');
  } on CliArgsException catch (e) {
    stdout.writeln(e.message);
    exit(64);
  }

  try {
    runSafetyChecks(
      cliArgs.sourcePath,
      cliArgs.destinationPath,
      force: cliArgs.force,
    );
  } on SafetyException catch (e) {
    stdout.writeln('pm: $e');
    exit(1);
  }

  if (tryRename(cliArgs.sourcePath, cliArgs.destinationPath)) {
    stdout.writeln('Moved (renamed instantly).');
    return;
  }

  final ScanResult scanResult = scan(
    cliArgs.sourcePath,
    cliArgs.destinationPath,
  );

  if (scanResult.tasks.isEmpty) {
    stdout.writeln('Nothing to move.');
    return;
  }

  final ProgressBar progress = ProgressBar(
    totalBytes: scanResult.totalBytes,
    totalFiles: scanResult.tasks.length,
  );

  final List<CopyFailure> failures = await moveViaCopy(
    scanResult: scanResult,
    sourcePath: cliArgs.sourcePath,
    progress: progress,
    concurrency: cliArgs.jobs,
  );

  progress.done();

  if (failures.isNotEmpty) {
    stdout.writeln('Completed with ${failures.length} error(s):');
    for (final CopyFailure failure in failures) {
      stdout.writeln('  ${failure.sourcePath}: ${failure.message}');
    }
    exit(1);
  }

  stdout.writeln('Moved ${scanResult.tasks.length} file(s).');
}

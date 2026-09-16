import 'dart:io';

import 'copy_pool.dart';
import 'paths.dart';
import 'progress.dart';
import 'scan.dart';

bool tryRename(String sourcePath, String destinationPath) {
  try {
    final Directory parent = Directory(dirName(destinationPath));
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }
    final FileSystemEntityType type = FileSystemEntity.typeSync(sourcePath);
    if (type == FileSystemEntityType.directory) {
      Directory(sourcePath).renameSync(destinationPath);
    } else {
      File(sourcePath).renameSync(destinationPath);
    }
    return true;
  } on FileSystemException {
    return false;
  }
}

Future<List<CopyFailure>> moveViaCopy({
  required ScanResult scanResult,
  required String sourcePath,
  required ProgressBar progress,
  required int concurrency,
}) async {
  final List<CopyFailure> failures = await runParallelCopy(
    tasks: scanResult.tasks,
    progress: progress,
    concurrency: concurrency,
  );

  if (failures.isNotEmpty) {
    return failures;
  }

  for (final FileTask task in scanResult.tasks) {
    final File sourceFile = File(task.sourcePath);
    final File destFile = File(task.destinationPath);
    if (!destFile.existsSync() ||
        destFile.lengthSync() != sourceFile.lengthSync()) {
      failures.add(
        CopyFailure(
          task.sourcePath,
          'Verification failed, refusing to delete source',
        ),
      );
    }
  }

  if (failures.isNotEmpty) {
    return failures;
  }

  if (scanResult.sourceIsDirectory) {
    Directory(sourcePath).deleteSync(recursive: true);
  } else {
    File(sourcePath).deleteSync();
  }

  return failures;
}

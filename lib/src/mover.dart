import 'dart:io';

import 'copy_pool.dart';
import 'directories.dart';
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
  required ProgressBar progress,
  required int concurrency,
}) async {
  final List<DirectoryTask> created = createDirectories(
    scanResult.directories,
  );
  final List<CopyFailure> failures = await runParallelCopy(
    tasks: scanResult.tasks,
    progress: progress,
    concurrency: concurrency,
  );
  applyDirectoryModes(created);

  if (failures.isNotEmpty) {
    return failures;
  }

  failures.addAll(_verify(scanResult));
  if (failures.isNotEmpty) {
    return failures;
  }

  failures.addAll(_removeSource(scanResult));
  return failures;
}

List<CopyFailure> _verify(ScanResult scanResult) {
  final List<CopyFailure> failures = <CopyFailure>[];
  for (final FileTask task in scanResult.tasks) {
    if (!_isCopied(task)) {
      failures.add(
        CopyFailure(
          task.sourcePath,
          'Verification failed, refusing to delete source',
        ),
      );
    }
  }
  for (final DirectoryTask directory in scanResult.directories) {
    if (!Directory(directory.destinationPath).existsSync()) {
      failures.add(
        CopyFailure(
          directory.sourcePath,
          'Verification failed, refusing to delete source',
        ),
      );
    }
  }
  return failures;
}

bool _isCopied(FileTask task) {
  final String? linkTarget = task.linkTarget;
  if (linkTarget != null) {
    final FileSystemEntityType type = FileSystemEntity.typeSync(
      task.destinationPath,
      followLinks: false,
    );
    return type == FileSystemEntityType.link &&
        Link(task.destinationPath).targetSync() == linkTarget;
  }
  final File sourceFile = File(task.sourcePath);
  final File destFile = File(task.destinationPath);
  return destFile.existsSync() &&
      destFile.lengthSync() == sourceFile.lengthSync();
}

List<CopyFailure> _removeSource(ScanResult scanResult) {
  final List<CopyFailure> failures = <CopyFailure>[];
  for (final FileTask task in scanResult.tasks) {
    try {
      if (task.isLink) {
        Link(task.sourcePath).deleteSync();
      } else {
        File(task.sourcePath).deleteSync();
      }
    } on FileSystemException catch (e) {
      failures.add(CopyFailure(task.sourcePath, e.message));
    }
  }

  if (failures.isNotEmpty) {
    return failures;
  }

  final List<DirectoryTask> ordered = List<DirectoryTask>.of(
    scanResult.directories,
  )..sort(
      (DirectoryTask a, DirectoryTask b) =>
          b.sourcePath.compareTo(a.sourcePath),
    );
  for (final DirectoryTask directory in ordered) {
    try {
      Directory(directory.sourcePath).deleteSync();
    } on FileSystemException {
      failures.add(
        CopyFailure(directory.sourcePath, 'Not empty, left in place'),
      );
    }
  }
  return failures;
}

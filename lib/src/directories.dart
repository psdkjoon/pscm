import 'dart:io';

import 'permissions.dart';
import 'scan.dart';

List<DirectoryTask> createDirectories(List<DirectoryTask> directories) {
  final List<DirectoryTask> created = <DirectoryTask>[];
  for (final DirectoryTask directory in directories) {
    final Directory target = Directory(directory.destinationPath);
    if (!target.existsSync()) {
      target.createSync(recursive: true);
      created.add(directory);
    }
  }
  return created;
}

void applyDirectoryModes(List<DirectoryTask> directories) {
  final List<DirectoryTask> ordered = List<DirectoryTask>.of(directories)
    ..sort(
      (DirectoryTask a, DirectoryTask b) =>
          b.destinationPath.compareTo(a.destinationPath),
    );
  for (final DirectoryTask directory in ordered) {
    setPermissions(directory.destinationPath, directory.mode);
  }
}

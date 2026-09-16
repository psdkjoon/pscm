import 'dart:io';

import 'paths.dart';

class FileTask {
  FileTask({
    required this.sourcePath,
    required this.destinationPath,
    required this.size,
  });

  final String sourcePath;
  final String destinationPath;
  final int size;
}

class ScanResult {
  ScanResult({
    required this.tasks,
    required this.totalBytes,
    required this.sourceIsDirectory,
  });

  final List<FileTask> tasks;
  final int totalBytes;
  final bool sourceIsDirectory;
}

ScanResult scan(String sourcePath, String destinationPath) {
  final FileSystemEntityType type = FileSystemEntity.typeSync(sourcePath);

  if (type == FileSystemEntityType.file) {
    final int size = File(sourcePath).lengthSync();
    return ScanResult(
      tasks: <FileTask>[
        FileTask(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          size: size,
        ),
      ],
      totalBytes: size,
      sourceIsDirectory: false,
    );
  }

  if (type == FileSystemEntityType.directory) {
    final List<FileTask> tasks = <FileTask>[];
    int totalBytes = 0;
    final Directory dir = Directory(sourcePath);
    final List<FileSystemEntity> entities = dir.listSync(recursive: true);
    for (final FileSystemEntity entity in entities) {
      if (entity is File) {
        final String relative = relativePath(entity.path, from: sourcePath);
        final String dest = joinPaths(destinationPath, relative);
        final int size = entity.lengthSync();
        totalBytes += size;
        tasks.add(
          FileTask(
            sourcePath: entity.path,
            destinationPath: dest,
            size: size,
          ),
        );
      }
    }
    return ScanResult(
      tasks: tasks,
      totalBytes: totalBytes,
      sourceIsDirectory: true,
    );
  }

  throw FileSystemException('Unsupported source type', sourcePath);
}

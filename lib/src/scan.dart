import 'dart:io';

import 'paths.dart';
import 'permissions.dart';

class FileTask {
  FileTask({
    required this.sourcePath,
    required this.destinationPath,
    required this.size,
    this.mode = 0,
    this.modified,
    this.linkTarget,
  });

  final String sourcePath;
  final String destinationPath;
  final int size;
  final int mode;
  final DateTime? modified;
  final String? linkTarget;

  bool get isLink => linkTarget != null;
}

class DirectoryTask {
  DirectoryTask({
    required this.sourcePath,
    required this.destinationPath,
    required this.mode,
  });

  final String sourcePath;
  final String destinationPath;
  final int mode;
}

class ScanResult {
  ScanResult({
    required this.tasks,
    required this.directories,
    required this.skipped,
    required this.totalBytes,
    required this.sourceIsDirectory,
  });

  final List<FileTask> tasks;
  final List<DirectoryTask> directories;
  final List<String> skipped;
  final int totalBytes;
  final bool sourceIsDirectory;
}

ScanResult scan(String sourcePath, String destinationPath) {
  final FileSystemEntityType type = FileSystemEntity.typeSync(sourcePath);

  if (type == FileSystemEntityType.file) {
    final FileStat stat = File(sourcePath).statSync();
    return ScanResult(
      tasks: <FileTask>[
        FileTask(
          sourcePath: sourcePath,
          destinationPath: destinationPath,
          size: stat.size,
          mode: stat.mode & permissionMask,
          modified: stat.modified,
        ),
      ],
      directories: <DirectoryTask>[],
      skipped: <String>[],
      totalBytes: stat.size,
      sourceIsDirectory: false,
    );
  }

  if (type == FileSystemEntityType.directory) {
    final List<FileTask> tasks = <FileTask>[];
    final List<DirectoryTask> directories = <DirectoryTask>[
      DirectoryTask(
        sourcePath: sourcePath,
        destinationPath: destinationPath,
        mode: Directory(sourcePath).statSync().mode & permissionMask,
      ),
    ];
    final List<String> skipped = <String>[];
    int totalBytes = 0;
    final Directory dir = Directory(sourcePath);
    final List<FileSystemEntity> entities = dir.listSync(
      recursive: true,
      followLinks: false,
    );
    for (final FileSystemEntity entity in entities) {
      final String relative = relativePath(entity.path, from: sourcePath);
      final String dest = joinPaths(destinationPath, relative);
      if (entity is Link) {
        tasks.add(
          FileTask(
            sourcePath: entity.path,
            destinationPath: dest,
            size: 0,
            linkTarget: entity.targetSync(),
          ),
        );
      } else if (entity is Directory) {
        directories.add(
          DirectoryTask(
            sourcePath: entity.path,
            destinationPath: dest,
            mode: entity.statSync().mode & permissionMask,
          ),
        );
      } else if (entity is File) {
        final FileStat stat = entity.statSync();
        if (stat.type != FileSystemEntityType.file) {
          skipped.add(entity.path);
          continue;
        }
        totalBytes += stat.size;
        tasks.add(
          FileTask(
            sourcePath: entity.path,
            destinationPath: dest,
            size: stat.size,
            mode: stat.mode & permissionMask,
            modified: stat.modified,
          ),
        );
      }
    }
    return ScanResult(
      tasks: tasks,
      directories: directories,
      skipped: skipped,
      totalBytes: totalBytes,
      sourceIsDirectory: true,
    );
  }

  throw FileSystemException('Unsupported source type', sourcePath);
}

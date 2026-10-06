import 'dart:io';

import 'fs_utils.dart';
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

class ScanIssue {
  ScanIssue(this.path, this.message);

  final String path;
  final String message;
}

class ScanResult {
  ScanResult({
    required this.tasks,
    required this.directories,
    required this.skipped,
    required this.issues,
    required this.totalBytes,
  });

  final List<FileTask> tasks;
  final List<DirectoryTask> directories;
  final List<String> skipped;
  final List<ScanIssue> issues;
  final int totalBytes;
}

class _Scanner {
  final List<FileTask> tasks = <FileTask>[];
  final List<DirectoryTask> directories = <DirectoryTask>[];
  final List<String> skipped = <String>[];
  final List<ScanIssue> issues = <ScanIssue>[];
  int totalBytes = 0;

  void addFile(String source, String destination) {
    final FileStat stat = FileStat.statSync(source);
    if (stat.type != FileSystemEntityType.file) {
      skipped.add(source);
      return;
    }
    totalBytes += stat.size;
    tasks.add(
      FileTask(
        sourcePath: source,
        destinationPath: destination,
        size: stat.size,
        mode: stat.mode & permissionMask,
        modified: stat.modified,
      ),
    );
  }

  void addLink(String source, String destination) {
    try {
      tasks.add(
        FileTask(
          sourcePath: source,
          destinationPath: destination,
          size: 0,
          linkTarget: Link(source).targetSync(),
        ),
      );
    } on FileSystemException catch (e) {
      issues.add(ScanIssue(source, describeError(e)));
    }
  }

  void addDirectory(String source, String destination) {
    final DirectoryTask root = DirectoryTask(
      sourcePath: source,
      destinationPath: destination,
      mode: FileStat.statSync(source).mode & permissionMask,
    );
    directories.add(root);

    final List<DirectoryTask> pending = <DirectoryTask>[root];
    while (pending.isNotEmpty) {
      final DirectoryTask current = pending.removeLast();
      final List<FileSystemEntity> entries;
      try {
        entries = Directory(current.sourcePath).listSync(followLinks: false);
      } on FileSystemException catch (e) {
        issues.add(ScanIssue(current.sourcePath, describeError(e)));
        continue;
      }
      for (final FileSystemEntity entry in entries) {
        final String destinationPath = joinPaths(
          current.destinationPath,
          baseName(entry.path),
        );
        if (entry is Link) {
          addLink(entry.path, destinationPath);
        } else if (entry is Directory) {
          final DirectoryTask child = DirectoryTask(
            sourcePath: entry.path,
            destinationPath: destinationPath,
            mode: FileStat.statSync(entry.path).mode & permissionMask,
          );
          directories.add(child);
          pending.add(child);
        } else if (entry is File) {
          addFile(entry.path, destinationPath);
        }
      }
    }
  }

  ScanResult build() {
    tasks.sort((FileTask a, FileTask b) => b.size.compareTo(a.size));
    return ScanResult(
      tasks: tasks,
      directories: directories,
      skipped: skipped,
      issues: issues,
      totalBytes: totalBytes,
    );
  }
}

ScanResult scan(
  String sourcePath,
  String destinationPath, {
  bool followSourceLink = true,
}) {
  FileSystemEntityType type = FileSystemEntity.typeSync(
    sourcePath,
    followLinks: false,
  );
  if (type == FileSystemEntityType.link && followSourceLink) {
    final FileSystemEntityType resolved = FileSystemEntity.typeSync(sourcePath);
    if (resolved != FileSystemEntityType.notFound) {
      type = resolved;
    }
  }

  final _Scanner scanner = _Scanner();
  if (type == FileSystemEntityType.link) {
    scanner.addLink(sourcePath, destinationPath);
  } else if (type == FileSystemEntityType.file) {
    scanner.addFile(sourcePath, destinationPath);
  } else if (type == FileSystemEntityType.directory) {
    scanner.addDirectory(sourcePath, destinationPath);
  } else {
    throw FileSystemException('Unsupported source type', sourcePath);
  }
  return scanner.build();
}

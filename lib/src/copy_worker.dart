import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'fs_utils.dart';
import 'paths.dart';
import 'permissions.dart';
import 'scan.dart';

class WorkerProgress {
  WorkerProgress(this.bytes);

  final int bytes;
}

class WorkerFileDone {
  WorkerFileDone();
}

class WorkerError {
  WorkerError(this.message, this.sourcePath);

  final String message;
  final String sourcePath;
}

class WorkerBatchDone {
  WorkerBatchDone();
}

const int copyBufferSize = 2 * 1024 * 1024;

String partPath(String destinationPath) {
  return joinPaths(
    dirName(destinationPath),
    '.${baseName(destinationPath)}.pscm-part',
  );
}

Future<void> copyWorkerEntry(SendPort events) async {
  final ReceivePort commands = ReceivePort();
  events.send(commands.sendPort);
  final Uint8List buffer = Uint8List(copyBufferSize);

  await for (final Object? message in commands) {
    if (message is! List<Object?>) {
      break;
    }
    for (final Object? item in message) {
      final FileTask task = item as FileTask;
      try {
        _copy(task, buffer, events);
        events.send(WorkerFileDone());
      } on Object catch (e) {
        events.send(WorkerError(describeError(e), task.sourcePath));
      }
    }
    events.send(WorkerBatchDone());
  }
  commands.close();
}

void _copy(FileTask task, Uint8List buffer, SendPort events) {
  final Directory parent = Directory(dirName(task.destinationPath));
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }

  final String? linkTarget = task.linkTarget;
  if (linkTarget != null) {
    _placeLink(task.destinationPath, linkTarget);
    return;
  }

  final String part = partPath(task.destinationPath);
  final RandomAccessFile input = File(task.sourcePath).openSync();
  bool renamed = false;
  try {
    final RandomAccessFile output = File(part).openSync(mode: FileMode.write);
    try {
      while (true) {
        final int read = input.readIntoSync(buffer);
        if (read == 0) {
          break;
        }
        output.writeFromSync(buffer, 0, read);
        events.send(WorkerProgress(read));
      }
    } finally {
      output.closeSync();
    }
    _applyMetadata(task, part);
    File(part).renameSync(task.destinationPath);
    renamed = true;
  } finally {
    input.closeSync();
    if (!renamed) {
      deleteQuietly(part);
    }
  }
}

void _placeLink(String path, String target) {
  final FileSystemEntityType type = FileSystemEntity.typeSync(
    path,
    followLinks: false,
  );
  if (type == FileSystemEntityType.link) {
    Link(path).deleteSync();
  } else if (type == FileSystemEntityType.file) {
    File(path).deleteSync();
  }
  Link(path).createSync(target);
}

void _applyMetadata(FileTask task, String path) {
  setPermissions(path, task.mode);
  final DateTime? modified = task.modified;
  if (modified == null) {
    return;
  }
  try {
    File(path).setLastModifiedSync(modified);
  } on FileSystemException {
    return;
  }
}

import 'dart:io';
import 'dart:isolate';

import 'paths.dart';

import 'scan.dart';

class WorkerRequest {
  WorkerRequest({required this.tasks, required this.sendPort});

  final List<FileTask> tasks;
  final SendPort sendPort;
}

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

class WorkerDone {
  WorkerDone();
}

const int copyBufferSize = 8 * 1024 * 1024;

void copyWorkerEntry(WorkerRequest request) async {
  for (final FileTask task in request.tasks) {
    try {
      await _copyFile(task, request.sendPort);
      request.sendPort.send(WorkerFileDone());
    } on Object catch (e) {
      request.sendPort.send(WorkerError(e.toString(), task.sourcePath));
    }
  }
  request.sendPort.send(WorkerDone());
}

Future<void> _copyFile(FileTask task, SendPort sendPort) async {
  final Directory destDir = Directory(dirName(task.destinationPath));
  if (!destDir.existsSync()) {
    destDir.createSync(recursive: true);
  }

  final RandomAccessFile input = File(
    task.sourcePath,
  ).openSync(mode: FileMode.read);
  final RandomAccessFile output = File(
    task.destinationPath,
  ).openSync(mode: FileMode.write);

  try {
    while (true) {
      final List<int> chunk = input.readSync(copyBufferSize);
      if (chunk.isEmpty) {
        break;
      }
      output.writeFromSync(chunk);
      sendPort.send(WorkerProgress(chunk.length));
    }
  } finally {
    input.closeSync();
    output.closeSync();
  }
}

import 'dart:isolate';

import 'copy_worker.dart';
import 'progress.dart';
import 'scan.dart';

class CopyFailure {
  CopyFailure(this.sourcePath, this.message);

  final String sourcePath;
  final String message;
}

Future<List<CopyFailure>> runParallelCopy({
  required List<FileTask> tasks,
  required ProgressBar progress,
  required int concurrency,
}) async {
  if (tasks.isEmpty) {
    return <CopyFailure>[];
  }

  final int workerCount = concurrency.clamp(1, tasks.length);
  final List<List<FileTask>> batches = List<List<FileTask>>.generate(
    workerCount,
    (_) => <FileTask>[],
  );
  for (int i = 0; i < tasks.length; i++) {
    batches[i % workerCount].add(tasks[i]);
  }

  final List<CopyFailure> failures = <CopyFailure>[];
  final List<Future<void>> futures = <Future<void>>[];

  for (final List<FileTask> batch in batches) {
    if (batch.isEmpty) {
      continue;
    }
    futures.add(_runBatch(batch, progress, failures));
  }

  await Future.wait(futures);
  return failures;
}

Future<void> _runBatch(
  List<FileTask> batch,
  ProgressBar progress,
  List<CopyFailure> failures,
) async {
  final ReceivePort receivePort = ReceivePort();
  final Isolate isolate = await Isolate.spawn(
    copyWorkerEntry,
    WorkerRequest(tasks: batch, sendPort: receivePort.sendPort),
  );

  await for (final Object? message in receivePort) {
    if (message is WorkerProgress) {
      progress.addBytes(message.bytes);
    } else if (message is WorkerFileDone) {
      progress.completeFile();
    } else if (message is WorkerError) {
      failures.add(CopyFailure(message.sourcePath, message.message));
      progress.completeFile();
    } else if (message is WorkerDone) {
      break;
    }
  }

  receivePort.close();
  isolate.kill();
}

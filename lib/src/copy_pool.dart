import 'dart:isolate';
import 'dart:math';

import 'copy_worker.dart';
import 'directories.dart';
import 'fs_utils.dart';
import 'progress.dart';
import 'scan.dart';

class CopyFailure {
  CopyFailure(this.sourcePath, this.message);

  final String sourcePath;
  final String message;
}

const int _batchBytes = 8 * 1024 * 1024;
const int _maxBatchFiles = 64;

class _Worker {
  _Worker(this.isolate);

  final Isolate isolate;
  List<FileTask> batch = <FileTask>[];
  int completed = 0;
}

class _Scheduler {
  _Scheduler(this.tasks, this.workers);

  final List<FileTask> tasks;
  final int workers;
  int _next = 0;

  bool get hasMore => _next < tasks.length;

  List<FileTask> take() {
    final int remaining = tasks.length - _next;
    final int share = (remaining / (workers * 2)).ceil();
    final int limit = min(_maxBatchFiles, max(1, share));
    final int start = _next;
    int bytes = 0;
    while (_next < tasks.length && _next - start < limit && bytes < _batchBytes) {
      bytes += tasks[_next].size;
      _next += 1;
    }
    return tasks.sublist(start, _next);
  }
}

final List<_Worker> _activeWorkers = <_Worker>[];

void cancelActiveCopy() {
  for (final _Worker worker in _activeWorkers) {
    worker.isolate.kill(priority: Isolate.immediate);
  }
  for (final _Worker worker in _activeWorkers) {
    for (final FileTask task in worker.batch) {
      deleteQuietly(partPath(task.destinationPath));
    }
  }
}

Future<List<CopyFailure>> copyScanResult({
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
  return failures;
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
  final _Scheduler scheduler = _Scheduler(tasks, workerCount);
  final List<CopyFailure> failures = <CopyFailure>[];

  await Future.wait(<Future<void>>[
    for (int i = 0; i < workerCount; i++)
      _runWorker(scheduler, progress, failures),
  ]);

  while (scheduler.hasMore) {
    for (final FileTask task in scheduler.take()) {
      failures.add(CopyFailure(task.sourcePath, 'Not copied, workers stopped'));
      progress.completeFile();
    }
  }
  return failures;
}

Future<void> _runWorker(
  _Scheduler scheduler,
  ProgressBar progress,
  List<CopyFailure> failures,
) async {
  final ReceivePort events = ReceivePort();
  final Isolate isolate;
  try {
    isolate = await Isolate.spawn(
      copyWorkerEntry,
      events.sendPort,
      onExit: events.sendPort,
      onError: events.sendPort,
    );
  } on Object catch (_) {
    events.close();
    return;
  }

  final _Worker worker = _Worker(isolate);
  _activeWorkers.add(worker);
  SendPort? commands;

  void dispatch() {
    final SendPort? port = commands;
    if (port == null) {
      return;
    }
    worker.batch = scheduler.hasMore ? scheduler.take() : <FileTask>[];
    worker.completed = 0;
    port.send(worker.batch.isEmpty ? null : worker.batch);
  }

  await for (final Object? message in events) {
    if (message is SendPort) {
      commands = message;
      dispatch();
    } else if (message is WorkerProgress) {
      progress.addBytes(message.bytes);
    } else if (message is WorkerFileDone) {
      worker.completed += 1;
      progress.completeFile();
    } else if (message is WorkerError) {
      worker.completed += 1;
      failures.add(CopyFailure(message.sourcePath, message.message));
      progress.completeFile();
    } else if (message is WorkerBatchDone) {
      dispatch();
    } else if (message is List<Object?>) {
      final String reason = message.isEmpty
          ? 'Worker crashed'
          : 'Worker crashed: ${message.first}';
      final List<FileTask> lost = worker.batch.sublist(worker.completed);
      if (lost.isEmpty) {
        failures.add(CopyFailure('(worker)', reason));
      }
      for (final FileTask task in lost) {
        failures.add(CopyFailure(task.sourcePath, reason));
        progress.completeFile();
      }
      worker.batch = <FileTask>[];
      worker.completed = 0;
    } else if (message == null) {
      break;
    }
  }

  events.close();
  _activeWorkers.remove(worker);
}

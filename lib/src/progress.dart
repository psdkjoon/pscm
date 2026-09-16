import 'dart:io';

class ProgressBar {
  ProgressBar({required this.totalBytes, required this.totalFiles});

  final int totalBytes;
  final int totalFiles;

  int bytesDone = 0;
  int filesDone = 0;
  final Stopwatch _stopwatch = Stopwatch()..start();
  DateTime _lastRender = DateTime.fromMillisecondsSinceEpoch(0);

  void addBytes(int bytes) {
    bytesDone += bytes;
    _maybeRender();
  }

  void completeFile() {
    filesDone += 1;
    _maybeRender();
  }

  void _maybeRender() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastRender).inMilliseconds < 80 &&
        filesDone < totalFiles) {
      return;
    }
    _lastRender = now;
    render();
  }

  void render() {
    final double ratio = totalBytes == 0 ? 1 : bytesDone / totalBytes;
    final int percent = (ratio * 100).clamp(0, 100).round();
    const int width = 30;
    final int filled = (width * ratio).clamp(0, width).round();
    final String bar = '${'#' * filled}${'-' * (width - filled)}';
    final double seconds = _stopwatch.elapsedMilliseconds / 1000;
    final double mbps = seconds == 0
        ? 0
        : (bytesDone / (1024 * 1024)) / seconds;
    final String line =
        '\r[$bar] $percent% '
        '($filesDone/$totalFiles files, '
        '${_formatBytes(bytesDone)}/${_formatBytes(totalBytes)}, '
        '${mbps.toStringAsFixed(1)} MB/s)';
    stdout.write(line.padRight(100));
  }

  void done() {
    render();
    stdout.write('\n');
  }
}

String _formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(1)}${units[unitIndex]}';
}

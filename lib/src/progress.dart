import 'dart:io';

class ProgressBar {
  ProgressBar({required this.totalBytes, required this.totalFiles});

  final int totalBytes;
  final int totalFiles;

  int bytesDone = 0;
  int filesDone = 0;
  final bool _enabled = stdout.hasTerminal;
  final Stopwatch _stopwatch = Stopwatch()..start();
  DateTime _lastRender = DateTime.fromMillisecondsSinceEpoch(0);

  double get _elapsedSeconds => _stopwatch.elapsedMilliseconds / 1000;

  double get _megabytesPerSecond {
    final double seconds = _elapsedSeconds;
    return seconds == 0 ? 0 : (bytesDone / (1024 * 1024)) / seconds;
  }

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

  double _ratio() {
    if (totalBytes > 0) {
      return bytesDone / totalBytes;
    }
    return totalFiles == 0 ? 1 : filesDone / totalFiles;
  }

  String _eta() {
    final double seconds = _elapsedSeconds;
    if (seconds < 1 || bytesDone == 0 || bytesDone >= totalBytes) {
      return '';
    }
    final int remaining = ((totalBytes - bytesDone) / (bytesDone / seconds))
        .round();
    return ', ETA ${_formatDuration(remaining)}';
  }

  void render() {
    if (!_enabled) {
      return;
    }
    final double ratio = _ratio();
    final int percent = (ratio * 100).clamp(0, 100).round();
    const int width = 30;
    final int filled = (width * ratio).clamp(0, width).round();
    final String bar = '${'#' * filled}${'-' * (width - filled)}';
    final String line =
        '[$bar] $percent% '
        '($filesDone/$totalFiles files, '
        '${formatBytes(bytesDone)}/${formatBytes(totalBytes)}, '
        '${_megabytesPerSecond.toStringAsFixed(1)} MB/s${_eta()})';
    stdout.write('\r${_fit(line)}');
  }

  void done() {
    _stopwatch.stop();
    if (!_enabled) {
      return;
    }
    render();
    stdout.write('\n');
  }

  void interrupt() {
    if (_enabled) {
      stdout.write('\n');
    }
  }

  String stats() {
    return '${formatBytes(bytesDone)} in '
        '${_elapsedSeconds.toStringAsFixed(1)}s, '
        '${_megabytesPerSecond.toStringAsFixed(1)} MB/s';
  }
}

String _fit(String line) {
  final int width = _terminalWidth();
  if (line.length > width) {
    return line.substring(0, width);
  }
  return line.padRight(width);
}

int _terminalWidth() {
  try {
    final int columns = stdout.terminalColumns - 1;
    return columns > 0 ? columns : 100;
  } on StdoutException {
    return 100;
  }
}

String _formatDuration(int totalSeconds) {
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String mm = minutes.toString().padLeft(2, '0');
  final String ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '${minutes.toString()}:$ss';
}

String formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  return '${value.toStringAsFixed(1)}${units[unitIndex]}';
}

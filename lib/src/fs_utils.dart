import 'dart:io';

String describeError(Object error) {
  if (error is FileSystemException) {
    final String reason = error.osError?.message ?? error.message;
    final String? path = error.path;
    if (path == null || path.isEmpty) {
      return reason;
    }
    return '$reason ($path)';
  }
  return error.toString();
}

void deleteQuietly(String path) {
  try {
    File(path).deleteSync();
  } on FileSystemException {
    return;
  }
}

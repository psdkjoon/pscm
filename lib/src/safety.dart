import 'dart:io';

import 'paths.dart';

class SafetyException implements Exception {
  SafetyException(this.message);

  final String message;

  @override
  String toString() => message;
}

void ensureSourceExists(String sourcePath) {
  final type = FileSystemEntity.typeSync(sourcePath);
  if (type == FileSystemEntityType.notFound) {
    throw SafetyException('Source does not exist: $sourcePath');
  }
}

void ensureNotSamePath(String sourcePath, String destinationPath) {
  final String a = absolutePath(sourcePath);
  final String b = absolutePath(destinationPath);
  if (a == b) {
    throw SafetyException('Source and destination are the same: $a');
  }
}

void ensureDestinationNotInsideSource(
  String sourcePath,
  String destinationPath,
) {
  final FileSystemEntityType sourceType = FileSystemEntity.typeSync(sourcePath);
  if (sourceType != FileSystemEntityType.directory) {
    return;
  }
  final String sourceAbs = absolutePath(sourcePath);
  final String destAbs = absolutePath(destinationPath);
  if (pathsEqual(destAbs, sourceAbs) || isWithin(sourceAbs, destAbs)) {
    throw SafetyException(
      'Destination "$destAbs" is inside source "$sourceAbs"',
    );
  }
}

void ensureDestinationAllowed(String destinationPath, {required bool force}) {
  final type = FileSystemEntity.typeSync(destinationPath);
  if (type == FileSystemEntityType.notFound) {
    return;
  }
  if (!force) {
    throw SafetyException(
      'Destination already exists: $destinationPath (use -f to overwrite)',
    );
  }
}

void runSafetyChecks(
  String sourcePath,
  String destinationPath, {
  required bool force,
}) {
  ensureSourceExists(sourcePath);
  ensureNotSamePath(sourcePath, destinationPath);
  ensureDestinationNotInsideSource(sourcePath, destinationPath);
  ensureDestinationAllowed(destinationPath, force: force);
}

import 'dart:io';

import 'paths.dart';

class SafetyException implements Exception {
  SafetyException(this.message);

  final String message;

  @override
  String toString() => message;
}

String resolveDestination(
  String sourcePath,
  String destinationPath, {
  required bool noTargetDirectory,
}) {
  if (noTargetDirectory) {
    return destinationPath;
  }
  final FileSystemEntityType existing = FileSystemEntity.typeSync(
    destinationPath,
  );
  final bool explicitDirectory = endsWithSeparator(destinationPath);
  final bool existingDirectory = existing == FileSystemEntityType.directory;

  if (explicitDirectory &&
      existing != FileSystemEntityType.notFound &&
      !existingDirectory) {
    throw SafetyException('Not a directory: $destinationPath');
  }
  if (!explicitDirectory && !existingDirectory) {
    return destinationPath;
  }

  final String name = baseName(absolutePath(sourcePath));
  if (name.isEmpty) {
    throw SafetyException('Cannot determine a name for source: $sourcePath');
  }
  return joinPaths(destinationPath, name);
}

void ensureSourceExists(String sourcePath) {
  final FileSystemEntityType type = FileSystemEntity.typeSync(
    sourcePath,
    followLinks: false,
  );
  if (type == FileSystemEntityType.notFound) {
    throw SafetyException('Source does not exist: $sourcePath');
  }
}

void ensureNotSamePath(
  String sourcePath,
  String destinationPath, {
  required bool followSourceLink,
}) {
  final String a = canonicalPath(sourcePath, resolveLast: followSourceLink);
  final String b = canonicalPath(destinationPath, resolveLast: false);
  if (a == b) {
    throw SafetyException('Source and destination are the same: $a');
  }
}

void ensureDestinationNotInsideSource(
  String sourcePath,
  String destinationPath, {
  required bool followSourceLink,
}) {
  final FileSystemEntityType sourceType = FileSystemEntity.typeSync(
    sourcePath,
    followLinks: followSourceLink,
  );
  if (sourceType != FileSystemEntityType.directory) {
    return;
  }
  final String source = canonicalPath(
    sourcePath,
    resolveLast: followSourceLink,
  );
  final String destination = canonicalPath(
    destinationPath,
    resolveLast: false,
  );
  if (destination == source || isWithin(source, destination)) {
    throw SafetyException(
      'Destination "$destination" is inside source "$source"',
    );
  }
}

void ensureDestinationAllowed(
  String sourcePath,
  String destinationPath, {
  required bool force,
  required bool followSourceLink,
}) {
  final FileSystemEntityType existing = FileSystemEntity.typeSync(
    destinationPath,
    followLinks: false,
  );
  if (existing == FileSystemEntityType.notFound) {
    return;
  }
  if (!force) {
    throw SafetyException(
      'Destination already exists: $destinationPath (use -f to overwrite)',
    );
  }

  final bool destinationIsDirectory =
      FileSystemEntity.typeSync(destinationPath) ==
      FileSystemEntityType.directory;
  final bool sourceIsDirectory =
      FileSystemEntity.typeSync(sourcePath, followLinks: followSourceLink) ==
      FileSystemEntityType.directory;

  if (destinationIsDirectory && !sourceIsDirectory) {
    throw SafetyException(
      'Cannot overwrite directory "$destinationPath" with a non-directory',
    );
  }
  if (!destinationIsDirectory && sourceIsDirectory) {
    throw SafetyException(
      'Cannot overwrite non-directory "$destinationPath" with a directory',
    );
  }
}

void runSafetyChecks(
  String sourcePath,
  String destinationPath, {
  required bool force,
  required bool followSourceLink,
}) {
  ensureSourceExists(sourcePath);
  ensureNotSamePath(
    sourcePath,
    destinationPath,
    followSourceLink: followSourceLink,
  );
  ensureDestinationNotInsideSource(
    sourcePath,
    destinationPath,
    followSourceLink: followSourceLink,
  );
  ensureDestinationAllowed(
    sourcePath,
    destinationPath,
    force: force,
    followSourceLink: followSourceLink,
  );
}

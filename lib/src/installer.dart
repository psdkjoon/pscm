import 'dart:convert';
import 'dart:io';

import 'completion.dart';
import 'fs_utils.dart';
import 'installer_payload.dart';
import 'paths.dart';
import 'permissions.dart';

const String _defaultPrefix = '/usr/local';
const int _executableMode = 493;

class InstallerException implements Exception {
  InstallerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InstallerArgs {
  InstallerArgs({required this.prefix, required this.uninstall});

  final String prefix;
  final bool uninstall;
}

InstallerArgs parseInstallerArgs(List<String> args) {
  String prefix = _defaultPrefix;
  bool uninstall = false;

  int i = 0;
  while (i < args.length) {
    final String arg = args[i];
    switch (arg) {
      case '--prefix':
        i += 1;
        if (i >= args.length) {
          throw InstallerException('Missing value for $arg');
        }
        prefix = args[i];
      case '--uninstall':
        uninstall = true;
      case '-h':
      case '--help':
        stdout.writeln(_usage());
        exit(0);
      default:
        throw InstallerException('Unknown option: $arg');
    }
    i += 1;
  }

  return InstallerArgs(prefix: prefix, uninstall: uninstall);
}

String _usage() {
  return 'pscm $installerVersion installer\n'
      '\n'
      'Usage: pscm-installer [--prefix DIR] [--uninstall]\n'
      '\n'
      '  --prefix DIR  install pc and pm into DIR/bin '
      '(default: $_defaultPrefix)\n'
      '  --uninstall   remove pc, pm and their shell completions\n'
      '  -h, --help    show this help';
}

Future<void> runInstaller(List<String> args) async {
  if (!Platform.isLinux) {
    throw InstallerException('This installer only supports Linux.');
  }

  final InstallerArgs installerArgs = parseInstallerArgs(args);

  if (!_isRoot()) {
    await _elevate(args);
    return;
  }

  final String binDirectory = joinPaths(
    absolutePath(installerArgs.prefix),
    'bin',
  );
  try {
    if (installerArgs.uninstall) {
      _uninstall(binDirectory);
    } else {
      _install(binDirectory);
    }
  } on FileSystemException catch (e) {
    throw InstallerException('${e.message} (${e.path ?? binDirectory})');
  }
}

bool _isRoot() {
  try {
    final ProcessResult result = Process.runSync('id', <String>['-u']);
    return result.stdout.toString().trim() == '0';
  } on ProcessException {
    return false;
  }
}

Future<void> _elevate(List<String> args) async {
  stdout.writeln('Root privileges are required, re-running with sudo ...');
  try {
    final Process process = await Process.start(
      'sudo',
      <String>[Platform.resolvedExecutable, ...args],
      mode: ProcessStartMode.inheritStdio,
    );
    exit(await process.exitCode);
  } on ProcessException {
    throw InstallerException(
      'Root privileges are required and sudo was not found',
    );
  }
}

void _install(String binDirectory) {
  if (pcPayload.isEmpty || pmPayload.isEmpty) {
    throw InstallerException('This build has no embedded payload.');
  }

  stdout.writeln(
    'Installing pscm $installerVersion (pc, pm) to $binDirectory ...',
  );
  Directory(binDirectory).createSync(recursive: true);
  _installBinary(binDirectory, 'pc', pcPayload);
  _installBinary(binDirectory, 'pm', pmPayload);

  final CompletionResult completion = installCompletions();
  stdout.writeln(completion.message);
  stdout.writeln('Installed pc and pm to $binDirectory');
}

void _installBinary(String directory, String name, List<String> payload) {
  final String target = joinPaths(directory, name);
  final String temporary = '$target.new';
  try {
    final List<int> bytes = gzip.decode(base64Decode(payload.join()));
    File(temporary).writeAsBytesSync(bytes, flush: true);
    if (!setPermissions(temporary, _executableMode)) {
      throw FileSystemException('Could not make file executable', temporary);
    }
    File(temporary).renameSync(target);
  } on Object {
    deleteQuietly(temporary);
    rethrow;
  }
}

void _uninstall(String binDirectory) {
  final CompletionResult completion = uninstallCompletions();
  stdout.writeln(completion.message);
  for (final String name in <String>['pc', 'pm']) {
    final File file = File(joinPaths(binDirectory, name));
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
  stdout.writeln('Removed pc and pm from $binDirectory');
}

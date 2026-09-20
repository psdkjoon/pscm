import 'dart:io';

import 'completion.dart';

class CliArgs {
  CliArgs({
    required this.sourcePath,
    required this.destinationPath,
    required this.force,
    required this.jobs,
  });

  final String sourcePath;
  final String destinationPath;
  final bool force;
  final int jobs;
}

class CliArgsException implements Exception {
  CliArgsException(this.message);

  final String message;

  @override
  String toString() => message;
}

CliArgs parseCliArgs(List<String> args, String toolName, String verb) {
  bool force = false;
  int jobs = Platform.numberOfProcessors;
  final List<String> positional = <String>[];

  int i = 0;
  while (i < args.length) {
    final String arg = args[i];
    switch (arg) {
      case '-f':
      case '--force':
        force = true;
      case '-j':
      case '--jobs':
        i += 1;
        if (i >= args.length) {
          throw CliArgsException('Missing value for $arg');
        }
        final int? parsed = int.tryParse(args[i]);
        if (parsed == null || parsed < 1) {
          throw CliArgsException('Invalid value for $arg: ${args[i]}');
        }
        jobs = parsed;
      case '-h':
      case '--help':
        stdout.writeln(_usage(toolName, verb));
        exit(0);
      case '--completion':
        i += 1;
        if (i >= args.length) {
          throw CliArgsException('Missing value for $arg');
        }
        final String? script = completionScript(args[i], toolName);
        if (script == null) {
          throw CliArgsException(
            'Unknown shell: ${args[i]} (expected bash, zsh or fish)',
          );
        }
        stdout.write(script);
        exit(0);
      case '--install-completion':
        final CompletionResult installResult = installCompletions();
        stdout.writeln(installResult.message);
        exit(installResult.success ? 0 : 1);
      case '--uninstall-completion':
        final CompletionResult uninstallResult = uninstallCompletions();
        stdout.writeln(uninstallResult.message);
        exit(uninstallResult.success ? 0 : 1);
      default:
        positional.add(arg);
    }
    i += 1;
  }

  if (positional.length != 2) {
    throw CliArgsException(_usage(toolName, verb));
  }

  return CliArgs(
    sourcePath: positional[0],
    destinationPath: positional[1],
    force: force,
    jobs: jobs,
  );
}

String _usage(String toolName, String verb) {
  return 'Usage: $toolName <source> <destination> [-f|--force] [-j|--jobs N]\n'
      '\n'
      '  $verb <source> to <destination>. Works for both files and\n'
      '  directories, no flag needed for directories.\n'
      '\n'
      '  -f, --force   overwrite destination if it already exists\n'
      '  -j, --jobs N  number of parallel workers (default: cpu count)\n'
      '  -h, --help    show this help\n'
      '  --completion SHELL      print completion script (bash, zsh, fish)\n'
      '  --install-completion    install shell completion for pc and pm\n'
      '                          (system-wide; re-run with sudo if needed)\n'
      '  --uninstall-completion  remove the installed completion files';
}

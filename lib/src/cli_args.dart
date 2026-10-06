import 'dart:io';
import 'dart:math';

import 'completion.dart';

const int _maxDefaultJobs = 8;

const Set<String> _valuedOptions = <String>{'-j', '--jobs', '--completion'};

class CliArgs {
  CliArgs({
    required this.sourcePath,
    required this.destinationPath,
    required this.force,
    required this.noTargetDirectory,
    required this.jobs,
  });

  final String sourcePath;
  final String destinationPath;
  final bool force;
  final bool noTargetDirectory;
  final int jobs;
}

class CliExit implements Exception {
  CliExit(this.output, {this.code = 0, this.toStderr = false});

  CliExit.usage(String message) : this('$message\n', code: 64, toStderr: true);

  final String output;
  final int code;
  final bool toStderr;
}

CliArgs parseCliArgs(List<String> args, String toolName, String verb) {
  bool force = false;
  bool noTargetDirectory = false;
  bool optionsEnded = false;
  int jobs = min(Platform.numberOfProcessors, _maxDefaultJobs);
  final List<String> positional = <String>[];

  int i = 0;
  while (i < args.length) {
    final String arg = args[i];
    i += 1;

    if (optionsEnded || arg == '-' || !arg.startsWith('-')) {
      positional.add(arg);
      continue;
    }
    if (arg == '--') {
      optionsEnded = true;
      continue;
    }

    String name = arg;
    String? attached;
    if (arg.startsWith('--')) {
      final int equals = arg.indexOf('=');
      if (equals > 0) {
        name = arg.substring(0, equals);
        attached = arg.substring(equals + 1);
      }
    } else if (arg.length > 2 && arg.startsWith('-j')) {
      name = '-j';
      attached = arg.substring(2);
    }

    if (attached != null && !_valuedOptions.contains(name)) {
      throw CliExit.usage('Option $name does not take a value');
    }

    switch (name) {
      case '-f':
      case '--force':
        force = true;
      case '-T':
      case '--no-target-directory':
        noTargetDirectory = true;
      case '-r':
      case '-R':
      case '--recursive':
        break;
      case '-j':
      case '--jobs':
        {
          final (String raw, int next) = _optionValue(
            name,
            attached,
            args,
            i,
          );
          final int? parsed = int.tryParse(raw);
          if (parsed == null || parsed < 1) {
            throw CliExit.usage('Invalid value for $name: $raw');
          }
          jobs = parsed;
          i = next;
        }
      case '-h':
      case '--help':
        throw CliExit('${_usage(toolName, verb)}\n');
      case '--completion':
        {
          final (String shell, int _) = _optionValue(
            name,
            attached,
            args,
            i,
          );
          final String? script = completionScript(shell, toolName);
          if (script == null) {
            throw CliExit.usage(
              'Unknown shell: $shell (expected bash, zsh or fish)',
            );
          }
          throw CliExit(script);
        }
      case '--install-completion':
        {
          final CompletionResult result = installCompletions();
          throw CliExit(
            '${result.message}\n',
            code: result.success ? 0 : 1,
            toStderr: !result.success,
          );
        }
      case '--uninstall-completion':
        {
          final CompletionResult result = uninstallCompletions();
          throw CliExit(
            '${result.message}\n',
            code: result.success ? 0 : 1,
            toStderr: !result.success,
          );
        }
      default:
        throw CliExit.usage('Unknown option: $arg\n\n${_usage(toolName, verb)}');
    }
  }

  if (positional.length != 2) {
    throw CliExit.usage(_usage(toolName, verb));
  }

  return CliArgs(
    sourcePath: positional[0],
    destinationPath: positional[1],
    force: force,
    noTargetDirectory: noTargetDirectory,
    jobs: jobs,
  );
}

(String, int) _optionValue(
  String name,
  String? attached,
  List<String> args,
  int index,
) {
  if (attached != null) {
    return (attached, index);
  }
  if (index >= args.length) {
    throw CliExit.usage('Missing value for $name');
  }
  return (args[index], index + 1);
}

String _usage(String toolName, String verb) {
  return 'Usage: $toolName <source> <destination> [options]\n'
      '\n'
      '  $verb <source> to <destination>. Works for files and directories,\n'
      '  no flag needed for directories. If <destination> is an existing\n'
      '  directory or ends with a slash, <source> is placed inside it.\n'
      '\n'
      '  -f, --force                overwrite destination if it already exists\n'
      '  -T, --no-target-directory  treat <destination> as the exact target\n'
      '                             path, never as a directory to place into\n'
      '  -j, --jobs N               number of parallel workers\n'
      '                             (default: cpu count, at most $_maxDefaultJobs)\n'
      '  -h, --help                 show this help\n'
      '  --completion SHELL         print completion script (bash, zsh, fish)\n'
      '  --install-completion       install shell completion for pc and pm\n'
      '                             (system-wide; re-run with sudo if needed)\n'
      '  --uninstall-completion     remove the installed completion files';
}

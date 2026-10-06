import 'dart:io';

const String _bashRoot = '/usr/share/bash-completion';
const String _zshRoot = '/usr/share/zsh';
const String _fishRoot = '/usr/share/fish';

const String _bashCompletionPath = '$_bashRoot/completions';
const String _zshCompletionPath = '$_zshRoot/site-functions';
const String _fishCompletionPath = '$_fishRoot/vendor_completions.d';

const List<String> _commandNames = <String>['pc', 'pm'];

const List<String> _flags = <String>[
  '-f',
  '--force',
  '-j',
  '--jobs',
  '-T',
  '--no-target-directory',
  '-h',
  '--help',
  '--completion',
  '--install-completion',
  '--uninstall-completion',
];

const String _bashTemplate = r'''
_pscm_complete() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  COMPREPLY=()

  case "$prev" in
    -j|--jobs)
      compopt +o default
      return 0
      ;;
    --completion)
      compopt +o default
      mapfile -t COMPREPLY < <(compgen -W "bash zsh fish" -- "$cur")
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    mapfile -t COMPREPLY < <(compgen -W "@flags@" -- "$cur")
  fi
}

complete -o default -F _pscm_complete pc pm
''';

const String _zshTemplate = r'''
#compdef @name@

_@name@() {
  _arguments \
    '(-f --force)'{-f,--force}'[overwrite destination if it exists]' \
    '(-T --no-target-directory)'{-T,--no-target-directory}'[treat destination as the exact target path]' \
    '(-j --jobs)'{-j,--jobs}'[number of parallel workers]:jobs:' \
    '(-h --help)'{-h,--help}'[show help]' \
    '--completion[print completion script]:shell:(bash zsh fish)' \
    '--install-completion[install shell completion]' \
    '--uninstall-completion[remove shell completion]' \
    '*:file:_files'
}

_@name@ "$@"
''';

const String _fishTemplate = r'''
complete -c @name@ -s f -l force -d 'overwrite destination if it exists'
complete -c @name@ -s T -l no-target-directory -d 'treat destination as the exact target path'
complete -c @name@ -s j -l jobs -x -d 'number of parallel workers'
complete -c @name@ -s h -l help -d 'show help'
complete -c @name@ -l completion -x -a 'bash zsh fish' -d 'print completion script'
complete -c @name@ -l install-completion -d 'install shell completion'
complete -c @name@ -l uninstall-completion -d 'remove shell completion'
''';

String _bashScript() {
  return _bashTemplate.replaceAll('@flags@', _flags.join(' '));
}

String _zshScript(String commandName) {
  return _zshTemplate.replaceAll('@name@', commandName);
}

String _fishScript(String commandName) {
  return _fishTemplate.replaceAll('@name@', commandName);
}

String? completionScript(String shell, String commandName) {
  return switch (shell) {
    'bash' => _bashScript(),
    'zsh' => _zshScript(commandName),
    'fish' => _fishScript(commandName),
    _ => null,
  };
}

class _CompletionFile {
  _CompletionFile({
    required this.shell,
    required this.root,
    required this.path,
    required this.content,
  });

  final String shell;
  final String root;
  final String path;
  final String content;
}

List<_CompletionFile> _completionFiles() {
  final List<_CompletionFile> files = <_CompletionFile>[];
  for (final String name in _commandNames) {
    files.add(
      _CompletionFile(
        shell: 'bash',
        root: _bashRoot,
        path: '$_bashCompletionPath/$name',
        content: _bashScript(),
      ),
    );
    files.add(
      _CompletionFile(
        shell: 'zsh',
        root: _zshRoot,
        path: '$_zshCompletionPath/_$name',
        content: _zshScript(name),
      ),
    );
    files.add(
      _CompletionFile(
        shell: 'fish',
        root: _fishRoot,
        path: '$_fishCompletionPath/$name.fish',
        content: _fishScript(name),
      ),
    );
  }
  return files;
}

class CompletionResult {
  CompletionResult({
    required this.success,
    required this.message,
    required this.needsSudo,
  });

  final bool success;
  final String message;
  final bool needsSudo;
}

CompletionResult _unsupportedPlatform() {
  return CompletionResult(
    success: false,
    message: 'Shell completion is only supported on Linux.',
    needsSudo: false,
  );
}

CompletionResult _writeFailure(FileSystemException e, String flag) {
  return CompletionResult(
    success: false,
    message:
        'Could not modify completion files: '
        '${e.osError?.message ?? e.message}\n'
        'Re-run with: sudo pc $flag',
    needsSudo: true,
  );
}

CompletionResult installCompletions() {
  if (!Platform.isLinux) {
    return _unsupportedPlatform();
  }
  final Set<String> installed = <String>{};
  final Set<String> skipped = <String>{};
  try {
    for (final _CompletionFile file in _completionFiles()) {
      if (!Directory(file.root).existsSync()) {
        skipped.add(file.shell);
        continue;
      }
      final File target = File(file.path);
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(file.content);
      installed.add(file.shell);
    }
  } on FileSystemException catch (e) {
    return _writeFailure(e, '--install-completion');
  }
  skipped.removeAll(installed);

  final StringBuffer message = StringBuffer();
  if (installed.isEmpty) {
    message.write('No supported shell found, no completions installed.');
  } else {
    message
      ..writeln('Installed ${installed.join(', ')} completions for pc and pm.')
      ..write('Restart your shell to pick them up.');
  }
  if (skipped.isNotEmpty) {
    message.write(
      '\nSkipped ${skipped.join(', ')} (not installed on this system).',
    );
  }
  if (installed.contains('bash')) {
    message.write('\nbash needs the bash-completion package.');
  }
  if (installed.contains('zsh')) {
    message.write(
      '\nIf zsh still does not complete, delete ~/.zcompdump* and restart it.',
    );
  }
  return CompletionResult(
    success: true,
    message: message.toString(),
    needsSudo: false,
  );
}

CompletionResult uninstallCompletions() {
  if (!Platform.isLinux) {
    return _unsupportedPlatform();
  }
  try {
    for (final _CompletionFile file in _completionFiles()) {
      final File target = File(file.path);
      if (target.existsSync()) {
        target.deleteSync();
      }
    }
    return CompletionResult(
      success: true,
      message: 'Removed bash, zsh and fish completions for pc and pm.',
      needsSudo: false,
    );
  } on FileSystemException catch (e) {
    return _writeFailure(e, '--uninstall-completion');
  }
}

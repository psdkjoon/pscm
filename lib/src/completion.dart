import 'dart:io';

const String _bashCompletionPath = '/usr/share/bash-completion/completions';
const String _zshCompletionPath = '/usr/share/zsh/site-functions';
const String _fishCompletionPath = '/usr/share/fish/vendor_completions.d';

const List<String> _commandNames = <String>['pc', 'pm'];

const List<String> _flags = <String>[
  '-f',
  '--force',
  '-j',
  '--jobs',
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
  _CompletionFile({required this.path, required this.content});

  final String path;
  final String content;
}

List<_CompletionFile> _completionFiles() {
  final List<_CompletionFile> files = <_CompletionFile>[];
  for (final String name in _commandNames) {
    files.add(
      _CompletionFile(
        path: '$_bashCompletionPath/$name',
        content: _bashScript(),
      ),
    );
    files.add(
      _CompletionFile(
        path: '$_zshCompletionPath/_$name',
        content: _zshScript(name),
      ),
    );
    files.add(
      _CompletionFile(
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
  try {
    for (final _CompletionFile file in _completionFiles()) {
      final File target = File(file.path);
      target.parent.createSync(recursive: true);
      target.writeAsStringSync(file.content);
    }
    return CompletionResult(
      success: true,
      message:
          'Installed bash, zsh and fish completions for pc and pm.\n'
          'Restart your shell to pick them up.\n'
          'bash needs the bash-completion package; if zsh still does not '
          'complete, delete ~/.zcompdump* and restart it.',
      needsSudo: false,
    );
  } on FileSystemException catch (e) {
    return _writeFailure(e, '--install-completion');
  }
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

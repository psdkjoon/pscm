import 'dart:io';

const String _bashCompletionPath =
    '/usr/share/bash-completion/completions';
const String _zshCompletionPath = '/usr/share/zsh/site-functions';

const List<String> _flags = <String>[
  '-f',
  '--force',
  '-j',
  '--jobs',
  '-h',
  '--help',
  '--install-completion',
];

String _bashScript() {
  final String flagList = _flags.join(' ');
  return '''
_pscm_complete() {
  local cur prev
  cur="\${COMP_WORDS[COMP_CWORD]}"
  if [[ "\$cur" == -* ]]; then
    COMPREPLY=( \$(compgen -W "$flagList" -- "\$cur") )
  else
    COMPREPLY=( \$(compgen -f -- "\$cur") )
  fi
}
complete -F _pscm_complete pc
complete -F _pscm_complete pm
''';
}

String _zshScript(String commandName) {
  _flags.join(' ');
  return '''
#compdef $commandName

_${commandName}() {
  _arguments \\
    '(-f --force)'{-f,--force}'[overwrite destination if it exists]' \\
    '(-j --jobs)'{-j,--jobs}'[number of parallel workers]:jobs:' \\
    '(-h --help)'{-h,--help}'[show help]' \\
    '--install-completion[install shell completion]' \\
    '*:file:_files'
}

_${commandName}
''';
}

class CompletionInstallResult {
  CompletionInstallResult({
    required this.success,
    required this.message,
    required this.needsSudo,
  });

  final bool success;
  final String message;
  final bool needsSudo;
}

CompletionInstallResult installCompletions() {
  try {
    final Directory bashDir = Directory(_bashCompletionPath);
    if (!bashDir.existsSync()) {
      bashDir.createSync(recursive: true);
    }
    File(
      '$_bashCompletionPath/pc',
    ).writeAsStringSync(_bashScript());
    File(
      '$_bashCompletionPath/pm',
    ).writeAsStringSync(_bashScript());

    final Directory zshDir = Directory(_zshCompletionPath);
    if (!zshDir.existsSync()) {
      zshDir.createSync(recursive: true);
    }
    File(
      '$_zshCompletionPath/_pc',
    ).writeAsStringSync(_zshScript('pc'));
    File(
      '$_zshCompletionPath/_pm',
    ).writeAsStringSync(_zshScript('pm'));

    return CompletionInstallResult(
      success: true,
      message:
          'Installed bash and zsh completions for pc and pm.\n'
          'Restart your shell (or source your rc file) to pick them up.',
      needsSudo: false,
    );
  } on FileSystemException {
    return CompletionInstallResult(
      success: false,
      message:
          'Could not write completion files (permission denied).\n'
          'Re-run with: sudo pc --install-completion',
      needsSudo: true,
    );
  }
}

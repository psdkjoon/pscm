import 'dart:io';

import 'package:pscm/src/installer.dart';

Future<void> main(List<String> args) async {
  try {
    await runInstaller(args);
  } on InstallerException catch (e) {
    stdout.writeln('pscm installer: ${e.message}');
    exit(1);
  }
}

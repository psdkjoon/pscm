import 'dart:io';

import 'package:pscm/src/runner.dart';

Future<void> main(List<String> args) async {
  exit(await runTool(Operation.move, args));
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const String _payloadPath = 'lib/src/installer_payload.dart';
const int _chunkSize = 16384;

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stdout.writeln(
      'Usage: dart run tool/build_installer.dart <pc> <pm> <output>',
    );
    exit(64);
  }

  final String pcPath = args[0];
  final String pmPath = args[1];
  final String output = args[2];

  final File payloadFile = File(_payloadPath);
  final String original = payloadFile.readAsStringSync();
  payloadFile.writeAsStringSync(_generate(_readVersion(), pcPath, pmPath));

  int code = 1;
  try {
    final Process process = await Process.start(
      Platform.resolvedExecutable,
      <String>['compile', 'exe', 'bin/installer.dart', '-o', output],
      mode: ProcessStartMode.inheritStdio,
    );
    code = await process.exitCode;
  } finally {
    payloadFile.writeAsStringSync(original);
  }

  if (code != 0) {
    exit(code);
  }
  stdout.writeln('Built $output');
}

String _readVersion() {
  final String pubspec = File('pubspec.yaml').readAsStringSync();
  final RegExpMatch? match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    stdout.writeln('No version found in pubspec.yaml');
    exit(1);
  }
  return match.group(1)!;
}

String _generate(String version, String pcPath, String pmPath) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('const String installerVersion = \'$version\';')
    ..writeln()
    ..writeln(_constant('pcPayload', pcPath))
    ..writeln(_constant('pmPayload', pmPath));
  return buffer.toString();
}

String _constant(String name, String path) {
  final List<int> compressed = GZipCodec(
    level: 9,
  ).encode(File(path).readAsBytesSync());
  final String encoded = base64Encode(compressed);
  final StringBuffer buffer = StringBuffer(
    'const List<String> $name = <String>[\n',
  );
  for (int i = 0; i < encoded.length; i += _chunkSize) {
    final int end = min(i + _chunkSize, encoded.length);
    buffer.writeln('  \'${encoded.substring(i, end)}\',');
  }
  buffer.write('];');
  return buffer.toString();
}

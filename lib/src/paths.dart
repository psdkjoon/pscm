import 'dart:io';

String pathSeparator() => Platform.isWindows ? '\\' : '/';

String joinPaths(String a, String b) {
  if (a.isEmpty) {
    return b;
  }
  final String sep = pathSeparator();
  final bool aHasTrailing = a.endsWith(sep);
  final bool bHasLeading = b.startsWith(sep);
  if (aHasTrailing && bHasLeading) {
    return a + b.substring(1);
  }
  if (!aHasTrailing && !bHasLeading) {
    return a + sep + b;
  }
  return a + b;
}

String dirName(String path) {
  final String sep = pathSeparator();
  String normalized = path;
  while (normalized.length > 1 && normalized.endsWith(sep)) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final int index = normalized.lastIndexOf(sep);
  if (index <= 0) {
    return index == 0 ? sep : '.';
  }
  return normalized.substring(0, index);
}

String absolutePath(String path) {
  if (_isAbsolute(path)) {
    return normalizePath(path);
  }
  return normalizePath(joinPaths(Directory.current.path, path));
}

bool _isAbsolute(String path) {
  if (Platform.isWindows) {
    return path.length >= 2 && path[1] == ':';
  }
  return path.startsWith('/');
}

String normalizePath(String path) {
  final String sep = pathSeparator();
  final bool absolute = _isAbsolute(path);
  final List<String> rawParts = path.split(RegExp(r'[\\/]'));
  final List<String> stack = <String>[];
  for (final String part in rawParts) {
    if (part.isEmpty || part == '.') {
      continue;
    }
    if (part == '..') {
      if (stack.isNotEmpty && stack.last != '..') {
        stack.removeLast();
      } else if (!absolute) {
        stack.add('..');
      }
      continue;
    }
    stack.add(part);
  }
  final String joined = stack.join(sep);
  if (absolute) {
    final String prefix = Platform.isWindows
        ? path.substring(0, 2) + sep
        : sep;
    return prefix + joined;
  }
  return joined.isEmpty ? '.' : joined;
}

String relativePath(String path, {required String from}) {
  final String pathAbs = absolutePath(path);
  final String fromAbs = absolutePath(from);
  final String sep = pathSeparator();
  final List<String> pathParts = pathAbs.split(sep)
    ..removeWhere((String e) => e.isEmpty);
  final List<String> fromParts = fromAbs.split(sep)
    ..removeWhere((String e) => e.isEmpty);

  int common = 0;
  while (common < pathParts.length &&
      common < fromParts.length &&
      pathParts[common] == fromParts[common]) {
    common += 1;
  }

  final List<String> up = List<String>.filled(
    fromParts.length - common,
    '..',
  );
  final List<String> down = pathParts.sublist(common);
  final List<String> result = <String>[...up, ...down];
  return result.isEmpty ? '.' : result.join(sep);
}

bool isWithin(String parent, String child) {
  final String parentAbs = absolutePath(parent);
  final String childAbs = absolutePath(child);
  final String sep = pathSeparator();
  final String parentWithSep = parentAbs.endsWith(sep)
      ? parentAbs
      : parentAbs + sep;
  return childAbs != parentAbs && childAbs.startsWith(parentWithSep);
}

bool pathsEqual(String a, String b) {
  return absolutePath(a) == absolutePath(b);
}

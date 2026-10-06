import 'dart:io';

bool get _windows => Platform.isWindows;

String pathSeparator() => _windows ? '\\' : '/';

bool isSeparator(String character) {
  return character == '/' || (_windows && character == '\\');
}

bool endsWithSeparator(String path) {
  return path.isNotEmpty && isSeparator(path[path.length - 1]);
}

String joinPaths(String a, String b) {
  if (a.isEmpty) {
    return b;
  }
  if (b.isEmpty) {
    return a;
  }
  final bool aTrailing = endsWithSeparator(a);
  final bool bLeading = isSeparator(b[0]);
  if (aTrailing && bLeading) {
    return a + b.substring(1);
  }
  if (!aTrailing && !bLeading) {
    return a + pathSeparator() + b;
  }
  return a + b;
}

String _stripTrailingSeparators(String path) {
  int end = path.length;
  while (end > 1 && isSeparator(path[end - 1])) {
    end -= 1;
  }
  return path.substring(0, end);
}

int _lastSeparator(String path) {
  final int slash = path.lastIndexOf('/');
  if (!_windows) {
    return slash;
  }
  final int backslash = path.lastIndexOf('\\');
  return slash > backslash ? slash : backslash;
}

String baseName(String path) {
  final String stripped = _stripTrailingSeparators(path);
  final int index = _lastSeparator(stripped);
  return index < 0 ? stripped : stripped.substring(index + 1);
}

String dirName(String path) {
  final String stripped = _stripTrailingSeparators(path);
  final int index = _lastSeparator(stripped);
  if (index < 0) {
    return '.';
  }
  if (index == 0) {
    return stripped.substring(0, 1);
  }
  final String parent = _stripTrailingSeparators(stripped.substring(0, index));
  if (_windows && parent.length == 2 && parent[1] == ':') {
    return parent + pathSeparator();
  }
  return parent;
}

bool _isAbsolute(String path) {
  if (_windows) {
    return path.length >= 2 && path[1] == ':';
  }
  return path.startsWith('/');
}

String normalizePath(String path) {
  final String sep = pathSeparator();
  final bool absolute = _isAbsolute(path);
  final List<String> parts = _windows
      ? path.split(RegExp(r'[\\/]'))
      : path.split('/');
  String drive = '';
  if (_windows && absolute) {
    drive = parts.removeAt(0);
  }
  final List<String> stack = <String>[];
  for (final String part in parts) {
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
    return _windows ? '$drive$sep$joined' : '$sep$joined';
  }
  return joined.isEmpty ? '.' : joined;
}

String absolutePath(String path) {
  if (_isAbsolute(path)) {
    return normalizePath(path);
  }
  return normalizePath(joinPaths(Directory.current.path, path));
}

String canonicalPath(String path, {bool resolveLast = true}) {
  final String absolute = absolutePath(path);
  if (!resolveLast) {
    final String parent = dirName(absolute);
    if (parent == absolute) {
      return absolute;
    }
    return joinPaths(canonicalPath(parent), baseName(absolute));
  }

  String existing = absolute;
  final List<String> missing = <String>[];
  while (FileSystemEntity.typeSync(existing, followLinks: false) ==
      FileSystemEntityType.notFound) {
    final String parent = dirName(existing);
    if (parent == existing || parent == '.') {
      return absolute;
    }
    missing.insert(0, baseName(existing));
    existing = parent;
  }

  String resolved;
  try {
    resolved = File(existing).resolveSymbolicLinksSync();
  } on FileSystemException {
    return absolute;
  }
  for (final String part in missing) {
    resolved = joinPaths(resolved, part);
  }
  return resolved;
}

bool isWithin(String parent, String child) {
  final String parentAbs = absolutePath(parent);
  final String childAbs = absolutePath(child);
  final String sep = pathSeparator();
  final String prefix = parentAbs.endsWith(sep) ? parentAbs : parentAbs + sep;
  return childAbs != parentAbs && childAbs.startsWith(prefix);
}

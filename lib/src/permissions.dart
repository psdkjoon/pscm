import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

typedef _ChmodNative = Int32 Function(Pointer<Uint8> path, Uint32 mode);
typedef _ChmodDart = int Function(Pointer<Uint8> path, int mode);
typedef _MallocNative = Pointer<Uint8> Function(IntPtr size);
typedef _MallocDart = Pointer<Uint8> Function(int size);
typedef _FreeNative = Void Function(Pointer<Uint8> pointer);
typedef _FreeDart = void Function(Pointer<Uint8> pointer);

const int permissionMask = 511;

final DynamicLibrary _libc = DynamicLibrary.process();

final _ChmodDart _chmod = _libc.lookupFunction<_ChmodNative, _ChmodDart>(
  'chmod',
);

final _MallocDart _malloc = _libc.lookupFunction<_MallocNative, _MallocDart>(
  'malloc',
);

final _FreeDart _free = _libc.lookupFunction<_FreeNative, _FreeDart>('free');

bool setPermissions(String path, int mode) {
  if (!Platform.isLinux) {
    return false;
  }
  final List<int> bytes = utf8.encode(path);
  final Pointer<Uint8> buffer = _malloc(bytes.length + 1);
  if (buffer.address == 0) {
    return false;
  }
  try {
    final Uint8List view = buffer.asTypedList(bytes.length + 1);
    view.setAll(0, bytes);
    view[bytes.length] = 0;
    return _chmod(buffer, mode) == 0;
  } finally {
    _free(buffer);
  }
}

import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'dart:io';

import 'package:ffi/ffi.dart' as pkg_ffi;

import '../domain/options.dart';

ffi.DynamicLibrary? _tryOpen(String path) {
  try {
    return ffi.DynamicLibrary.open(path);
  } catch (_) {
    return null;
  }
}

String? _envLibraryPath() {
  // Generic override for CI/dev where the dynamic loader search path may not
  // include the Rust build output directory.
  return Platform.environment['PIXO_LIBRARY_PATH'];
}

String? _findDevLibraryCandidate(String fileName) {
  if (const bool.fromEnvironment('dart.vm.product')) {
    return null;
  }

  final candidates = <String>[];

  // Common dev layout when this repo is the CWD.
  candidates.add('${Directory.current.path}/rust/target/release/$fileName');
  candidates.add('${Directory.current.path}/target/release/$fileName');

  // Walk up from the running script location to find a repo root.
  final scriptFile = File.fromUri(Platform.script);
  var dir = scriptFile.parent;
  for (var i = 0; i < 8; i++) {
    candidates.add('${dir.path}/rust/target/release/$fileName');
    candidates.add('${dir.path}/target/release/$fileName');
    dir = dir.parent;
  }

  for (final c in candidates) {
    if (File(c).existsSync()) {
      return c;
    }
  }
  return null;
}

ffi.DynamicLibrary _openLibrary() {
  if (Platform.isMacOS) {
    final lib = _tryOpen('libpixo.dylib');
    if (lib != null) return lib;

    final override = _envLibraryPath();
    if (override != null && override.isNotEmpty) {
      final overridden = _tryOpen(override);
      if (overridden != null) return overridden;
    }

    final devCandidate = _findDevLibraryCandidate('libpixo.dylib');
    if (devCandidate != null) {
      final devLib = _tryOpen(devCandidate);
      if (devLib != null) return devLib;
    }

    return ffi.DynamicLibrary.open('libpixo.dylib');
  } else if (Platform.isIOS) {
    return ffi.DynamicLibrary.process();
  } else if (Platform.isAndroid || Platform.isLinux) {
    final lib = _tryOpen('libpixo.so');
    if (lib != null) return lib;

    final override = _envLibraryPath();
    if (override != null && override.isNotEmpty) {
      final overridden = _tryOpen(override);
      if (overridden != null) return overridden;
    }

    final devCandidate = _findDevLibraryCandidate('libpixo.so');
    if (devCandidate != null) {
      final devLib = _tryOpen(devCandidate);
      if (devLib != null) return devLib;
    }

    return ffi.DynamicLibrary.open('libpixo.so');
  } else if (Platform.isWindows) {
    final lib = _tryOpen('pixo.dll');
    if (lib != null) return lib;

    final override = _envLibraryPath();
    if (override != null && override.isNotEmpty) {
      final overridden = _tryOpen(override);
      if (overridden != null) return overridden;
    }

    final devCandidate = _findDevLibraryCandidate('pixo.dll');
    if (devCandidate != null) {
      final devLib = _tryOpen(devCandidate);
      if (devLib != null) return devLib;
    }

    return ffi.DynamicLibrary.open('pixo.dll');
  }
  throw UnsupportedError('pixo_flutter: unsupported platform');
}

final ffi.DynamicLibrary _lib = _openLibrary();

class _Status {
  static const int ok = 0;
}

typedef _EncodePngNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.IntPtr,
  ffi.Uint32,
  ffi.Uint32,
  ffi.Uint8,
  ffi.Uint8,
  ffi.Bool,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
  ffi.Pointer<ffi.IntPtr>,
  ffi.Pointer<ffi.Pointer<ffi.Char>>,
);

typedef _EncodePngDart = int Function(
  ffi.Pointer<ffi.Uint8>,
  int,
  int,
  int,
  int,
  int,
  bool,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
  ffi.Pointer<ffi.IntPtr>,
  ffi.Pointer<ffi.Pointer<ffi.Char>>,
);

typedef _EncodeJpegNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.IntPtr,
  ffi.Uint32,
  ffi.Uint32,
  ffi.Uint8,
  ffi.Uint8,
  ffi.Uint8,
  ffi.Bool,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
  ffi.Pointer<ffi.IntPtr>,
  ffi.Pointer<ffi.Pointer<ffi.Char>>,
);

typedef _EncodeJpegDart = int Function(
  ffi.Pointer<ffi.Uint8>,
  int,
  int,
  int,
  int,
  int,
  int,
  bool,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
  ffi.Pointer<ffi.IntPtr>,
  ffi.Pointer<ffi.Pointer<ffi.Char>>,
);

typedef _FreeBufferNative = ffi.Void Function(
  ffi.Pointer<ffi.Uint8>,
  ffi.IntPtr,
);

typedef _FreeBufferDart = void Function(
  ffi.Pointer<ffi.Uint8>,
  int,
);

typedef _FreeCStringNative = ffi.Void Function(
  ffi.Pointer<ffi.Char>,
);

typedef _FreeCStringDart = void Function(
  ffi.Pointer<ffi.Char>,
);

final _EncodePngDart _pixoEncodePng = _lib
    .lookupFunction<_EncodePngNative, _EncodePngDart>('pixo_encode_png_pixels');

final _EncodeJpegDart _pixoEncodeJpeg = _lib
    .lookupFunction<_EncodeJpegNative, _EncodeJpegDart>('pixo_encode_jpeg_pixels');

final _FreeBufferDart _pixoFreeBuffer =
    _lib.lookupFunction<_FreeBufferNative, _FreeBufferDart>('pixo_free_buffer');

final _FreeCStringDart _pixoFreeCString = _lib
    .lookupFunction<_FreeCStringNative, _FreeCStringDart>('pixo_free_cstring');

Future<Uint8List> encodePngPixels(
  Uint8List pixels,
  PixoPngOptions options,
) async {
  final dataPtr = pkg_ffi.malloc<ffi.Uint8>(pixels.length);
  final dataView = dataPtr.asTypedList(pixels.length);
  dataView.setAll(0, pixels);

  final outPtrPtr = pkg_ffi.malloc<ffi.Pointer<ffi.Uint8>>();
  final outLenPtr = pkg_ffi.malloc<ffi.IntPtr>();
  final errPtrPtr = pkg_ffi.malloc<ffi.Pointer<ffi.Char>>();
  errPtrPtr.value = ffi.nullptr;

  try {
    final status = _pixoEncodePng(
      dataPtr,
      pixels.length,
      options.width,
      options.height,
      options.colorType,
      options.preset,
      options.lossless,
      outPtrPtr,
      outLenPtr,
      errPtrPtr,
    );

    if (status != _Status.ok) {
      final errPtr = errPtrPtr.value;
      String message = 'pixo PNG encode failed (status=$status)';
      if (errPtr != ffi.nullptr) {
        message = errPtr.cast<pkg_ffi.Utf8>().toDartString();
      }
      if (errPtr != ffi.nullptr) {
        _pixoFreeCString(errPtr);
      }
      throw StateError(message);
    }

    final outPtr = outPtrPtr.value;
    final outLen = outLenPtr.value;
    if (outPtr == ffi.nullptr || outLen <= 0) {
      throw StateError('pixo PNG encode returned empty buffer');
    }

    final outView = outPtr.asTypedList(outLen);
    final result = Uint8List.fromList(outView);
    _pixoFreeBuffer(outPtr, outLen);
    return result;
  } finally {
    pkg_ffi.malloc.free(dataPtr);
    pkg_ffi.malloc.free(outPtrPtr);
    pkg_ffi.malloc.free(outLenPtr);
    final errPtr = errPtrPtr.value;
    if (errPtr != ffi.nullptr) {
      _pixoFreeCString(errPtr);
    }
    pkg_ffi.malloc.free(errPtrPtr);
  }
}

Future<Uint8List> encodeJpegPixels(
  Uint8List pixels,
  PixoJpegOptions options,
) async {
  final dataPtr = pkg_ffi.malloc<ffi.Uint8>(pixels.length);
  final dataView = dataPtr.asTypedList(pixels.length);
  dataView.setAll(0, pixels);

  final outPtrPtr = pkg_ffi.malloc<ffi.Pointer<ffi.Uint8>>();
  final outLenPtr = pkg_ffi.malloc<ffi.IntPtr>();
  final errPtrPtr = pkg_ffi.malloc<ffi.Pointer<ffi.Char>>();
  errPtrPtr.value = ffi.nullptr;

  try {
    final status = _pixoEncodeJpeg(
      dataPtr,
      pixels.length,
      options.width,
      options.height,
      options.colorType,
      options.quality,
      options.preset,
      options.subsampling420,
      outPtrPtr,
      outLenPtr,
      errPtrPtr,
    );

    if (status != _Status.ok) {
      final errPtr = errPtrPtr.value;
      String message = 'pixo JPEG encode failed (status=$status)';
      if (errPtr != ffi.nullptr) {
        message = errPtr.cast<pkg_ffi.Utf8>().toDartString();
      }
      if (errPtr != ffi.nullptr) {
        _pixoFreeCString(errPtr);
      }
      throw StateError(message);
    }

    final outPtr = outPtrPtr.value;
    final outLen = outLenPtr.value;
    if (outPtr == ffi.nullptr || outLen <= 0) {
      throw StateError('pixo JPEG encode returned empty buffer');
    }

    final outView = outPtr.asTypedList(outLen);
    final result = Uint8List.fromList(outView);
    _pixoFreeBuffer(outPtr, outLen);
    return result;
  } finally {
    pkg_ffi.malloc.free(dataPtr);
    pkg_ffi.malloc.free(outPtrPtr);
    pkg_ffi.malloc.free(outLenPtr);
    final errPtr = errPtrPtr.value;
    if (errPtr != ffi.nullptr) {
      _pixoFreeCString(errPtr);
    }
    pkg_ffi.malloc.free(errPtrPtr);
  }
}

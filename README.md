# pixo_flutter

Flutter plugin package that wraps the Rust [pixo](https://github.com/leerob/pixo) image
compression library via Dart FFI.

This package exposes a small, hexagonally-structured API to encode raw pixel
buffers as PNG or JPEG using pixo's high-performance encoders.

## Architecture

- `lib/src/domain/`
  - `options.dart` — domain models for PNG/JPEG options and encoded images.
- `lib/src/application/`
  - `pixo_service.dart` — application service façade used by callers.
- `lib/src/infrastructure/`
  - `backend_ffi.dart` — native bindings to the Rust `pixo` library via FFI.
  - `backend_web_stub.dart` — placeholder for a future Flutter web backend.

The public entry point is `PixoService` plus the domain option types:

```dart
import 'package:pixo_flutter/pixo_flutter.dart';
```

## Building the native library

This package expects a native `pixo` library built with the `ffi` feature.

From the `pixo_flutter` root, build the native library:

```bash
dart run tool/build_native.dart
```

This calls:

```bash
cargo build --release --features ffi
```

Resulting artifacts (paths from repo root):

- macOS:   `rust/target/release/libpixo.dylib`
- iOS:     build/link into the Xcode target (Dart uses `DynamicLibrary.process()`)
- Android: `rust/target/release/libpixo.so`
- Linux:   `rust/target/release/libpixo.so`
- Windows: `rust/target/release/pixo.dll`

You are responsible for copying these into your Flutter app or plugin
according to Flutter's platform conventions (e.g. `android/app/src/main/jniLibs`,
`ios/Runner`, `macos/Runner`, etc.).

## Usage

```dart
import 'dart:typed_data';
import 'package:pixo_flutter/pixo_flutter.dart';

Future<void> example() async {
  final service = PixoService();

  // 1x1 red RGBA pixel
  final pngPixels = Uint8List.fromList([255, 0, 0, 255]);

  final pngOptions = PixoPngOptions(
    width: 1,
    height: 1,
    colorType: 3, // Rgba
    preset: 1,    // balanced
    lossless: true,
  );

  final png = await service.encodePngPixels(pngPixels, pngOptions);

  // JPEG: RGB only (strip alpha yourself if needed)
  final jpegPixels = Uint8List.fromList([255, 0, 0]);

  final jpegOptions = PixoJpegOptions(
    width: 1,
    height: 1,
    colorType: 2,  // Rgb
    quality: 85,
    preset: 1,
    subsampling420: true,
  );

  final jpeg = await service.encodeJpegPixels(jpegPixels, jpegOptions);

  // png.bytes / jpeg.bytes now hold compressed image data.
}
```

## Testing

The `test/compress_test.dart` file contains basic integration tests which:

- Encode a 1x1 PNG and assert the standard PNG signature bytes.
- Encode a 1x1 JPEG and assert the JPEG SOI marker.
- Decode `test/test.png` and encode it to PNG and JPEG, asserting signatures.

To run tests:

```bash
export PIXO_LIBRARY_PATH="$PWD/rust/target/release/libpixo.dylib"
flutter test
```

To run the integration test on a device/emulator:

```bash
export PIXO_LIBRARY_PATH="$PWD/rust/target/release/libpixo.dylib"
flutter test integration_test
```

## Example app

An example app is available under `example/`.

## Web support

Currently the Flutter web backend is a stub and will throw `UnsupportedError`.
Future work can integrate the existing pixo WASM build via JS interop.

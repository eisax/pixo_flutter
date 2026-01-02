import 'dart:typed_data';

import '../domain/options.dart';
import '../infrastructure/backend_ffi.dart'
    if (dart.library.html) '../infrastructure/backend_web_stub.dart' as backend;

/// Application service providing a simple facade over the pixo encoders.
class PixoService {
  const PixoService();

  Future<PixoEncodedImage> encodePngPixels(
    Uint8List pixels,
    PixoPngOptions options,
  ) async {
    final bytes = await backend.encodePngPixels(pixels, options);
    return PixoEncodedImage(bytes, PixoFormat.png);
  }

  Future<PixoEncodedImage> encodeJpegPixels(
    Uint8List pixels,
    PixoJpegOptions options,
  ) async {
    final bytes = await backend.encodeJpegPixels(pixels, options);
    return PixoEncodedImage(bytes, PixoFormat.jpeg);
  }
}

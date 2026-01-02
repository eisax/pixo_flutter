import 'dart:typed_data';

import '../domain/options.dart';

Future<Uint8List> encodePngPixels(
  Uint8List pixels,
  PixoPngOptions options,
) async {
  throw UnsupportedError('pixo_flutter: Flutter web backend not yet implemented');
}

Future<Uint8List> encodeJpegPixels(
  Uint8List pixels,
  PixoJpegOptions options,
) async {
  throw UnsupportedError('pixo_flutter: Flutter web backend not yet implemented');
}

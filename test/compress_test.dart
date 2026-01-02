import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pixo_flutter/pixo_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pixo_flutter compression', () {
    test('encodes 1x1 PNG RGBA with correct signature', () async {
      final service = PixoService();
      final pixels = Uint8List.fromList([255, 0, 0, 255]); // 1x1 red RGBA
      final options = PixoPngOptions(
        width: 1,
        height: 1,
        colorType: 3, // Rgba
        preset: 1,
        lossless: true,
      );

      final result = await service.encodePngPixels(pixels, options);
      expect(result.format, PixoFormat.png);
      expect(result.bytes.length, greaterThan(8));
      expect(result.bytes.sublist(0, 8), equals(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]));
    });

    test('encodes 1x1 JPEG RGB with correct SOI marker', () async {
      final service = PixoService();
      final pixels = Uint8List.fromList([255, 0, 0]); // 1x1 red RGB
      final options = PixoJpegOptions(
        width: 1,
        height: 1,
        colorType: 2, // Rgb
        quality: 85,
        preset: 1,
        subsampling420: false,
      );

      final result = await service.encodeJpegPixels(pixels, options);
      expect(result.format, PixoFormat.jpeg);
      expect(result.bytes.length, greaterThan(2));
      expect(result.bytes.sublist(0, 2), equals(const [0xFF, 0xD8]));
    });

    test('encodes provided test PNG into PNG and JPEG', () async {
      final byteData = await rootBundle.load('test/test.png');
      final bytes = byteData.buffer.asUint8List();

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(pixels, isNotNull);
      final rgba = pixels!.buffer.asUint8List();

      final width = image.width;
      final height = image.height;

      final service = PixoService();

      final png = await service.encodePngPixels(
        rgba,
        PixoPngOptions(
          width: width,
          height: height,
          colorType: 3,
          preset: 1,
          lossless: true,
        ),
      );
      expect(png.format, PixoFormat.png);
      expect(png.bytes.sublist(0, 8), equals(const [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]));

      // JPEG requires RGB (no alpha)
      final rgb = Uint8List(width * height * 3);
      for (int si = 0, di = 0; si < rgba.length; si += 4, di += 3) {
        rgb[di] = rgba[si];
        rgb[di + 1] = rgba[si + 1];
        rgb[di + 2] = rgba[si + 2];
      }

      final jpeg = await service.encodeJpegPixels(
        rgb,
        PixoJpegOptions(
          width: width,
          height: height,
          colorType: 2,
          quality: 85,
          preset: 1,
          subsampling420: true,
        ),
      );
      expect(jpeg.format, PixoFormat.jpeg);
      expect(jpeg.bytes.sublist(0, 2), equals(const [0xFF, 0xD8]));
    });
  });
}

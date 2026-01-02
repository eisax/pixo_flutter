import 'dart:typed_data';

/// Supported image formats for encoding.
enum PixoFormat {
  png,
  jpeg,
}

/// PNG encoding options (domain model).
class PixoPngOptions {
  final int width;
  final int height;
  /// Color type: 0=Gray, 1=GrayAlpha, 2=Rgb, 3=Rgba.
  final int colorType;
  /// Preset: 0=fast, 1=balanced, 2=max.
  final int preset;
  /// If true, use lossless encoding. If false, enable lossy quantization.
  final bool lossless;

  const PixoPngOptions({
    required this.width,
    required this.height,
    this.colorType = 3,
    this.preset = 1,
    this.lossless = true,
  });
}

/// JPEG encoding options (domain model).
class PixoJpegOptions {
  final int width;
  final int height;
  /// Color type: 0=Gray, 2=Rgb.
  final int colorType;
  /// Quality 1-100.
  final int quality;
  /// Preset: 0=fast, 1=balanced, 2=max.
  final int preset;
  /// If true, use 4:2:0 subsampling; otherwise 4:4:4.
  final bool subsampling420;

  const PixoJpegOptions({
    required this.width,
    required this.height,
    this.colorType = 2,
    this.quality = 85,
    this.preset = 1,
    this.subsampling420 = true,
  });
}

/// Encoded image result.
class PixoEncodedImage {
  final Uint8List bytes;
  final PixoFormat format;

  const PixoEncodedImage(this.bytes, this.format);
}

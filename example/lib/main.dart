import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pixo_flutter/pixo_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pixo_flutter example',
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: ExampleScreen(),
          ),
        ),
      ),
    );
  }
}

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  String _status = 'Idle';

  Future<void> _run() async {
    setState(() {
      _status = 'Encoding...';
    });

    try {
      final service = PixoService();

      final pngPixels = Uint8List.fromList([255, 0, 0, 255]);
      final png = await service.encodePngPixels(
        pngPixels,
        const PixoPngOptions(width: 1, height: 1, colorType: 3, preset: 1, lossless: true),
      );

      final jpegPixels = Uint8List.fromList([255, 0, 0]);
      final jpeg = await service.encodeJpegPixels(
        jpegPixels,
        const PixoJpegOptions(width: 1, height: 1, colorType: 2, quality: 85, preset: 1, subsampling420: true),
      );

      setState(() {
        _status = 'OK\nPNG: ${png.bytes.length} bytes\nJPEG: ${jpeg.bytes.length} bytes';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'pixo_flutter example',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _run,
          child: const Text('Run encode'),
        ),
        const SizedBox(height: 12),
        Text(_status),
      ],
    );
  }
}

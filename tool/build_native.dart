import 'dart:io';

/// Build the native pixo Rust library located under `rust/` with the `ffi`
/// feature enabled.
///
/// Usage (from the pixo_flutter root):
///   dart run tool/build_native.dart
Future<void> main() async {
  final repoRoot = Directory.current.path; // pixo_flutter/
  final rustRoot = Directory('$repoRoot/rust').path;
  final cargo = Platform.isWindows ? 'cargo.exe' : 'cargo';

  stdout.writeln('Building pixo native library with ffi feature...');
  stdout.writeln('Rust crate root: $rustRoot');

  final result = await Process.run(
    cargo,
    ['build', '--release', '--features', 'ffi'],
    workingDirectory: rustRoot,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    stderr.writeln('cargo build failed with exit code ${result.exitCode}');
    exit(result.exitCode);
  }

  stdout.writeln('Build completed.');
  stdout.writeln('Artifacts are under: rust/target/release/');
  stdout.writeln('Copy the built library into your Flutter app as described in:');
  stdout.writeln('  android/README.md, ios/README.md, macos/README.md, linux/README.md, windows/README.md');
}

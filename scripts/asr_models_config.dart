import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Prints the Remote Config `asr_models` value for a whisper.cpp model hosted in Firebase Storage.
Future<void> main(List<String> args) async {
  String? bucket;
  String? url;
  String? path;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--bucket' when i + 1 < args.length:
        bucket = args[++i];
      case '--url' when i + 1 < args.length:
        url = args[++i];
      default:
        path = args[i];
    }
  }
  if (path == null || (bucket == null && url == null)) {
    stderr.writeln(
      'Usage: dart run scripts/asr_models_config.dart '
      '(--bucket <bucket> | --url <download url>) <path/to/ggml-*.bin>',
    );
    exit(64);
  }
  final file = File(path);
  final name = file.uri.pathSegments.last;
  if (!file.existsSync()) {
    stderr.writeln('No file at $path');
    exit(66);
  }
  if (!name.startsWith('ggml-') || !name.endsWith('.bin')) {
    stderr.writeln(
      'The app only picks up whisper.cpp files named ggml-<model>.bin; got $name',
    );
    exit(65);
  }
  final bytes = file.lengthSync();
  final digest = await sha256.bind(file.openRead()).first;
  final downloadUrl =
      url ??
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o/'
          '${Uri.encodeComponent('models/$name')}?alt=media';
  final matrix = jsonDecode(
    File('assets/capability_matrix.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final languages = (matrix['languages'] as Map<String, dynamic>).keys;
  final spec = {
    'file': name,
    'url': downloadUrl,
    'bytes': bytes,
    'sha256': digest.toString(),
  };
  stdout.writeln(
    const JsonEncoder.withIndent('  ')
        .convert({for (final lang in languages) lang: spec}),
  );
}

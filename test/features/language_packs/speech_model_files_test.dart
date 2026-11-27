import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/features/language_packs/data/model/pack_models.dart';
import 'package:lingo_mate/features/language_packs/data/repository/pack_repository.dart';

/// Builds a `.tar.bz2` holding a transducer folder and sample audio.
List<int> _modelArchive() {
  final archive = Archive();
  for (final name in [
    'sherpa-onnx-zipformer-vi-test/encoder.int8.onnx',
    'sherpa-onnx-zipformer-vi-test/decoder.onnx',
    'sherpa-onnx-zipformer-vi-test/joiner.int8.onnx',
    'sherpa-onnx-zipformer-vi-test/tokens.txt',
    'sherpa-onnx-zipformer-vi-test/test_wavs/0.wav',
  ]) {
    final bytes = utf8.encode(name);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(archive));
}

void main() {
  late Directory dir;
  late HttpServer server;
  late List<int> body;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('models');
    body = _modelArchive();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((request) {
        request.response
          ..contentLength = body.length
          ..add(body)
          ..close();
      });
    addTearDown(() async {
      await server.close(force: true);
      await dir.delete(recursive: true);
    });
  });

  AsrModelSpec spec() => AsrModelSpec(
    fileName: 'sherpa-onnx-zipformer-vi-test.tar.bz2',
    url: 'http://${server.address.address}:${server.port}/model.tar.bz2',
    bytes: body.length,
    sha256: sha256.convert(body).toString(),
  );

  test('a .tar.bz2 model names the folder it unpacks into', () {
    expect(spec().isArchive, isTrue);
    expect(spec().folderName, 'sherpa-onnx-zipformer-vi-test');
    const single = AsrModelSpec(fileName: 'ggml-base.bin', url: 'u', bytes: 1);
    expect(single.isArchive, isFalse);
    expect(single.folderName, 'ggml-base.bin');
  });

  test(
    'downloads, checks and unpacks an archive model, then deletes it',
    () async {
      final files = HttpSpeechModelFiles(directory: () async => dir);
      final progress = <double>[];

      expect(await files.exists(spec()), isFalse);
      await files.download(spec(), progress.add);

      final folder = Directory('${dir.path}/sherpa-onnx-zipformer-vi-test');
      expect(await files.exists(spec()), isTrue);
      expect(File('${folder.path}/joiner.int8.onnx').existsSync(), isTrue);
      expect(Directory('${folder.path}/test_wavs').existsSync(), isFalse);
      expect(progress.last, 1);
      expect(
        dir.listSync().map(
          (e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last,
        ),
        ['sherpa-onnx-zipformer-vi-test'],
      );

      await files.delete(spec());
      expect(await files.exists(spec()), isFalse);
    },
  );

  test('rejects an archive whose checksum does not match', () async {
    final files = HttpSpeechModelFiles(directory: () async => dir);
    final bad = AsrModelSpec(
      fileName: spec().fileName,
      url: spec().url,
      bytes: body.length,
      sha256: '0' * 64,
    );

    await expectLater(files.download(bad, (_) {}), throwsStateError);
    expect(dir.listSync(), isEmpty);
  });
}

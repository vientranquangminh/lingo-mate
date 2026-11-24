import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/asr/asr_models.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('models');
    addTearDown(() => dir.delete(recursive: true));
  });

  /// Creates an empty file under the models folder.
  Future<void> touch(String path) async {
    final file = File('${dir.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const [0]);
  }

  test('finds whisper.cpp files, sherpa folders and Silero', () async {
    await touch('ggml-small-q5_1.bin');
    await touch('ggml-base.bin');
    await touch('silero_vad.onnx');
    await touch('sherpa-onnx-whisper-base/base-encoder.onnx');
    await touch('sherpa-onnx-whisper-base/base-encoder.int8.onnx');
    await touch('sherpa-onnx-whisper-base/base-decoder.int8.onnx');
    await touch('sherpa-onnx-whisper-base/base-tokens.txt');
    await touch('notes.txt');

    final catalog = await AsrModelStore(dir).scan();

    expect(catalog.whisperCpp.map((m) => m.name), ['base', 'small-q5_1']);
    expect(catalog.sileroVad, endsWith('silero_vad.onnx'));
    final sherpa = catalog.sherpaWhisper.single;
    expect(sherpa.name, 'base');
    expect(sherpa.encoder, endsWith('base-encoder.int8.onnx'));
    expect(sherpa.decoder, endsWith('base-decoder.int8.onnx'));
    expect(sherpa.tokens, endsWith('base-tokens.txt'));
  });

  test('skips a sherpa folder missing a file', () async {
    await touch('sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx');
    await touch('sherpa-onnx-whisper-tiny/tiny-tokens.txt');

    final catalog = await AsrModelStore(dir).scan();

    expect(catalog.sherpaWhisper, isEmpty);
    expect(catalog.isEmpty, isTrue);
  });

  test('returns an empty catalog for a missing folder', () async {
    final catalog = await AsrModelStore(Directory('${dir.path}/missing'))
        .scan();

    expect(catalog.isEmpty, isTrue);
    expect(catalog.sileroVad, isNull);
  });

  test('converts PCM16 to floats between -1 and 1', () {
    final floats = pcm16ToFloat(Int16List.fromList([0, 16384, -32768, 32767]));

    expect(floats[0], 0);
    expect(floats[1], 0.5);
    expect(floats[2], -1);
    expect(floats[3], closeTo(1, 0.0001));
  });
}

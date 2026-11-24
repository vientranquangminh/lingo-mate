import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/audio/wav_decoder.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/features/devtools/data/model/benchmark_models.dart';
import 'package:lingo_mate/features/devtools/data/repository/benchmark_csv.dart';
import 'package:lingo_mate/features/devtools/data/repository/benchmark_files.dart';
import 'package:lingo_mate/features/devtools/data/repository/benchmark_runner.dart';

import '../../core/audio/audio_test_utils.dart';

/// Builds a WAV file around PCM16 bytes.
Uint8List wav(Uint8List pcmBytes, {int sampleRate = 16000, int channels = 1}) {
  final header = ByteData(44)
    ..setUint32(4, 36 + pcmBytes.length, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, channels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * channels * 2, Endian.little)
    ..setUint16(32, channels * 2, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(40, pcmBytes.length, Endian.little);
  final bytes = header.buffer.asUint8List()
    ..setAll(0, ascii.encode('RIFF'))
    ..setAll(8, ascii.encode('WAVEfmt '))
    ..setAll(36, ascii.encode('data'));
  return Uint8List.fromList([...bytes, ...pcmBytes]);
}

/// ASR that answers with a fixed text after advancing the fake clock.
class _FakeAsr implements SpeechRecognizerEngine {
  _FakeAsr(this.advance);

  final void Function(int ms) advance;
  int calls = 0;

  @override
  String get id => 'fake-asr';

  @override
  Future<void> ensureReady(String lang) async {}

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    advance(300);
    calls++;
    return AsrResult(text: 'utterance $calls, "quoted"', lang: hintLang ?? '');
  }
}

/// Translator that echoes the text after advancing the fake clock.
class _FakeTranslator implements TextTranslatorEngine {
  _FakeTranslator(this.advance, {this.fail = false});

  final void Function(int ms) advance;
  final bool fail;
  final requests = <TranslateRequest>[];

  @override
  String get id => 'fake-mt';

  @override
  EngineKind get kind => EngineKind.standard;

  @override
  Future<bool> isAvailable(String from, String to) async => true;

  @override
  Future<Translation> translate(TranslateRequest request) async {
    requests.add(request);
    advance(200);
    if (fail) {
      throw StateError('quota');
    }
    return Translation(text: 'EN ${request.text}', engine: kind);
  }
}

void main() {
  group('WavDecoder', () {
    test('returns the PCM data of a 16 kHz mono file', () {
      final pcmBytes = pcm(40, amplitude: 9);

      expect(WavDecoder.decodePcm16(wav(pcmBytes)), pcmBytes);
    });

    test('rejects other sample rates and stereo', () {
      expect(
        () => WavDecoder.decodePcm16(wav(pcm(20), sampleRate: 44100)),
        throwsA(isA<WavFormatException>()),
      );
      expect(
        () => WavDecoder.decodePcm16(wav(pcm(20), channels: 2)),
        throwsA(isA<WavFormatException>()),
      );
    });

    test('rejects non-WAV bytes', () {
      expect(
        () => WavDecoder.decodePcm16(Uint8List.fromList(List.filled(64, 1))),
        throwsA(isA<WavFormatException>()),
      );
    });
  });

  group('BenchmarkCsv', () {
    test('quotes cells with commas, quotes and line breaks', () {
      final csv = BenchmarkCsv.encode([
        const BenchmarkRow(
          clipId: 'C01',
          lang: 'vi',
          pipeline: 'a+b',
          utterance: 0,
          segmentStartMs: 0,
          segmentEndMs: 900,
          asrMs: 300,
          transcript: 'xin chào, "bạn"\nkhỏe',
        ),
      ]);

      final lines = csv.split('\n');
      expect(lines.first, BenchmarkRow.header.join(','));
      expect(csv, contains('"xin chào, ""bạn""\nkhỏe"'));
      expect(lines[1], startsWith('C01,vi,a+b,0,0,900,300,,'));
    });
  });

  group('BenchmarkRunner', () {
    late int now;
    late BenchmarkRunner runner;
    const clip = BenchmarkClip(
      id: 'C10',
      file: 'C10.wav',
      lang: 'vi',
      scenario: 'turns',
      referenceTranscript: 'ref',
      referenceTranslation: {'en': 'ref en'},
    );
    final twoUtterances = Uint8List.fromList([
      ...pcm(1000, amplitude: 4000),
      ...pcm(800),
      ...pcm(1000, amplitude: 4000),
      ...pcm(800),
    ]);

    setUp(() {
      now = 0;
      runner = BenchmarkRunner(nowMs: () => now, realTime: false);
    });

    test('writes one row per utterance with stage latencies', () async {
      void advance(int ms) => now += ms;
      final translator = _FakeTranslator(advance);

      final rows = await runner.runClip(
        clip: clip,
        pcm: twoUtterances,
        pipeline: BenchmarkPipeline(
          asr: _FakeAsr(advance),
          translator: translator,
        ),
      );

      expect(rows, hasLength(2));
      expect(rows.map((r) => r.utterance), [0, 1]);
      expect(rows.first.pipeline, 'fake-asr+fake-mt');
      expect(rows.first.segmentEndMs, 1000);
      expect(rows.first.asrMs, 300);
      expect(rows.first.translationMs, 500);
      expect(rows.first.translation, startsWith('EN utterance 1'));
      expect(rows.first.referenceTranscript, 'ref');
      expect(rows.first.targetLang, 'en');
      expect(rows.first.referenceTranslation, 'ref en');
      expect(translator.requests.first.to, 'en');
      expect(translator.requests[1].context, [rows.first.transcript]);
    });

    test('records an ASR-only pipeline without translation columns', () async {
      final rows = await runner.runClip(
        clip: clip,
        pcm: twoUtterances,
        pipeline: BenchmarkPipeline(asr: _FakeAsr((ms) => now += ms)),
      );

      expect(rows.first.pipeline, 'fake-asr');
      expect(rows.first.translationMs, isNull);
      expect(rows.first.targetLang, isEmpty);
    });

    test('keeps going and records the error when a stage fails', () async {
      void advance(int ms) => now += ms;

      final rows = await runner.runClip(
        clip: clip,
        pcm: twoUtterances,
        pipeline: BenchmarkPipeline(
          asr: _FakeAsr(advance),
          translator: _FakeTranslator(advance, fail: true),
        ),
      );

      expect(rows, hasLength(2));
      expect(rows.every((r) => r.error.contains('quota')), isTrue);
      expect(rows.first.transcript, isNotEmpty);
    });
  });

  group('BenchmarkPipeline', () {
    test('translates English clips to Vietnamese and others to English', () {
      final pipeline = BenchmarkPipeline(asr: _FakeAsr((_) {}));

      expect(pipeline.targetFor('en'), 'vi');
      expect(pipeline.targetFor('vi'), 'en');
      expect(pipeline.targetFor('ja'), 'en');
      expect(
        BenchmarkPipeline(
          asr: _FakeAsr((_) {}),
          targetLang: 'ja',
        ).targetFor('vi'),
        'ja',
      );
    });
  });

  group('BenchmarkFiles', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('benchmark');
      addTearDown(() => dir.delete(recursive: true));
    });

    test('reads the manifest and clip audio, and writes a CSV', () async {
      await File('${dir.path}/manifest.json').writeAsString(
        jsonEncode([
          {
            'id': 'C01',
            'file': 'C01_vi_quiet.wav',
            'lang': 'vi',
            'scenario': 'quiet',
            'reference_transcript': 'xin chào',
            'reference_translation': {'en': 'hello'},
          },
        ]),
      );
      final pcmBytes = pcm(40, amplitude: 3);
      await File('${dir.path}/C01_vi_quiet.wav').writeAsBytes(wav(pcmBytes));
      final files = BenchmarkFiles(dir);

      final clips = await files.readManifest();
      final audio = await files.readPcm(clips.single);
      final csv = await files.writeCsv(const [], DateTime(2026, 11, 24, 9));

      expect(clips.single.referenceTranslation, {'en': 'hello'});
      expect(audio, pcmBytes);
      expect(csv.path, endsWith('results-2026-11-24_09-00-00-000.csv'));
      expect(await csv.readAsString(), startsWith('clip,lang,pipeline'));
    });

    test('returns no clips without a manifest', () async {
      expect(await BenchmarkFiles(dir).readManifest(), isEmpty);
    });
  });
}

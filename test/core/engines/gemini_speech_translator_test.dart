import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/translate/gemini_speech_translator.dart';

void main() {
  final segment = AudioSegment(
    samples: Int16List.fromList([1, -2, 3]),
    startMs: 0,
    endMs: 1000,
    speechRatio: 1,
  );

  test('sends the sentence as WAV and reads the JSON reply', () async {
    late String sentSystem;
    late Uint8List sentWav;
    late String sentUser;
    final translator = GeminiSpeechTranslator(({
      required system,
      required wav,
      required user,
    }) async {
      sentSystem = system;
      sentWav = wav;
      sentUser = user;
      return '{"lang": "ja", "original": "こんにちは", "translation": "Xin chào"}';
    });

    final heard = await translator.translate(
      segment: segment,
      from: const ['ja'],
      to: 'vi',
      context: const ['はじめまして'],
    );

    expect(
      heard,
      const SpeechTranslation(
        lang: 'ja',
        original: 'こんにちは',
        translation: 'Xin chào',
      ),
    );
    expect(sentSystem, contains('spoken in ja'));
    expect(sentSystem, contains('into vi'));
    expect(sentUser, contains('はじめまして'));
    expect(sentWav.length, 44 + 6);
    expect(String.fromCharCodes(sentWav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(sentWav.sublist(8, 12)), 'WAVE');
    expect(
      ByteData.sublistView(sentWav).getUint32(24, Endian.little),
      AudioFormat.sampleRate,
    );
  });

  test('lists the candidates when the language is not known', () {
    expect(
      GeminiSpeechTranslator.system(from: const ['ja', 'en'], to: 'vi'),
      contains('one of ja, en'),
    );
  });

  test('returns null when nothing intelligible was said', () {
    expect(
      GeminiSpeechTranslator.parse(
        '{"lang": "", "original": "", "translation": ""}',
        from: const ['ja'],
        to: 'vi',
      ),
      isNull,
    );
  });

  test('falls back to the first candidate for an unexpected language', () {
    final heard = GeminiSpeechTranslator.parse(
      '{"lang": "zh", "original": "你好", "translation": "Xin chào"}',
      from: const ['ja', 'en'],
      to: 'vi',
    );

    expect(heard?.lang, 'ja');
  });

  test('throws on a reply that is not the expected JSON', () {
    expect(
      () => GeminiSpeechTranslator.parse(
        'Xin chào',
        from: const ['ja'],
        to: 'vi',
      ),
      throwsFormatException,
    );
    expect(
      () => GeminiSpeechTranslator.parse(
        '{"lang": "ja", "original": "こんにちは", "translation": ""}',
        from: const ['ja'],
        to: 'vi',
      ),
      throwsFormatException,
    );
  });
}

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/engines/asr/language_routed_recognizer.dart';
import 'package:lingo_mate/core/engines/asr/sherpa_transducer_engine.dart';
import 'package:lingo_mate/core/engines/engines.dart';

/// Recognizer that answers with its own name and remembers the hints it got.
class _Named implements SpeechRecognizerEngine {
  _Named(this.name, {this.detected});

  final String name;
  final String? detected;
  final hints = <String?>[];

  @override
  String get id => name;

  @override
  bool get supportsPartials => true;

  @override
  Future<void> ensureReady(String lang) async {}

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    hints.add(hintLang);
    return AsrResult(text: name, lang: hintLang ?? '');
  }

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async => detected;
}

void main() {
  final segment = AudioSegment(
    samples: Int16List(160),
    startMs: 0,
    endMs: 10,
    speechRatio: 1,
  );

  test(
    'sends a language to its own recognizer and the rest to the fallback',
    () async {
      final vietnamese = _Named('vi-transducer');
      final whisper = _Named('whisper', detected: 'en');
      final router = LanguageRoutedRecognizer(
        byLanguage: {'vi': vietnamese},
        fallback: whisper,
      );

      expect(
        (await router.transcribe(segment, hintLang: 'vi')).text,
        'vi-transducer',
      );
      expect(
        (await router.transcribe(segment, hintLang: 'en')).text,
        'whisper',
      );
      expect(
        await router.detectLanguage(segment, candidates: const ['vi', 'en']),
        'en',
      );
    },
  );

  test('without a fallback, other languages hear nothing', () async {
    final router = LanguageRoutedRecognizer(
      byLanguage: {'vi': _Named('vi-transducer')},
    );

    expect((await router.transcribe(segment, hintLang: 'ja')).text, isEmpty);
    expect(
      await router.detectLanguage(segment, candidates: const ['vi']),
      'vi',
    );
    expect(
      await router.detectLanguage(segment, candidates: const ['vi', 'en']),
      isNull,
    );
  });

  test('turns the transducer output into sentence case', () {
    expect(
      SherpaTransducerEngine.sentenceCase(' NHỮNG NƠI ĐÃ KHỐNG CHẾ ĐƯỢC '),
      'Những nơi đã khống chế được',
    );
    expect(SherpaTransducerEngine.sentenceCase(''), '');
  });
}

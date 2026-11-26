import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/translate/gemini_speech_translator.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/features/listen/data/model/listen_models.dart';
import 'package:lingo_mate/features/listen/data/notifier/listen_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../conversation/conversation_fakes.dart';

void main() {
  const languages = LanguagePair('ja', 'vi');
  late ConversationFakes fakes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['ja', 'en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    addTearDown(fakes.db.close);
  });

  /// Builds a container with listen kept alive for [key].
  Future<ProviderContainer> build([LanguagePair key = languages]) async {
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        listenClockProvider.overrideWithValue(() => fakes.nowMs),
      ],
    );
    addTearDown(c.dispose);
    c.listen(listenProvider(key), (_, _) {});
    await pumpEventQueue();
    return c;
  }

  ListenNotifier notifier(
    ProviderContainer c, [
    LanguagePair key = languages,
  ]) => c.read(listenProvider(key).notifier);

  /// Speaks [ms] of speech followed by enough silence to end the segment.
  Future<void> speak({int ms = 1000}) async {
    fakes.nowMs += ms + 700;
    fakes.capture
      ..add(pcm(ms, amplitude: 4000))
      ..add(pcm(700));
    await pumpEventQueue();
  }

  test(
    'Start streams captions with original and translation (AC-03.1)',
    () async {
      fakes.recognizer.texts.addAll(['こんにちは', 'ありがとう']);
      final c = await build();

      await notifier(c).start();
      await speak();
      await speak();

      final state = c.read(listenProvider(languages));
      expect(state.listening, isTrue);
      expect(fakes.recognizer.hints, ['ja', 'ja']);
      expect(state.captions.map((c) => c.original), ['こんにちは', 'ありがとう']);
      expect(state.captions.map((c) => c.translation), [
        '[vi] こんにちは',
        '[vi] ありがとう',
      ]);
      expect(state.captions.first.status, CaptionStatus.translated);
      expect(fakes.standard.requests.last.context, ['こんにちは']);
    },
  );

  test(
    'shows the words heard so far, then replaces them with the caption',
    () async {
      fakes.recognizer
        ..supportsPartials = true
        ..texts.addAll(['こんに', 'こんにちは']);
      final c = await build();
      await notifier(c).start();

      fakes.capture.add(pcm(1200, amplitude: 4000));
      await pumpEventQueue();

      expect(c.read(listenProvider(languages)).draft, 'こんに');
      expect(c.read(listenProvider(languages)).captions, isEmpty);

      fakes.capture.add(pcm(700));
      await pumpEventQueue();

      final state = c.read(listenProvider(languages));
      expect(state.draft, isNull);
      expect(state.captions.single.original, 'こんにちは');
    },
  );

  test(
    'on Standard, Gemini hears and translates the sentence in one call',
    () async {
      fakes.recognizer.texts.add('should not be used');
      fakes.speech = GeminiSpeechTranslator(
        ({required system, required wav, required user}) async =>
            '{"lang": "ja", "original": "こんにちは", "translation": "Xin chào"}',
      );
      final c = await build();
      await notifier(c).start();

      await speak();

      final caption = c.read(listenProvider(languages)).captions.single;
      expect(caption.original, 'こんにちは');
      expect(caption.translation, 'Xin chào');
      expect(caption.status, CaptionStatus.translated);
      expect(caption.engine, EngineKind.standard);
      expect(fakes.recognizer.hints, isEmpty);
      expect(fakes.standard.requests, isEmpty);
    },
  );

  test(
    'when Gemini cannot hear the sentence, the phone recognizes it',
    () async {
      fakes.recognizer.texts.add('こんにちは');
      fakes.speech = GeminiSpeechTranslator(
        ({required system, required wav, required user}) async =>
            throw StateError('down'),
      );
      final c = await build();
      await notifier(c).start();

      await speak();

      final caption = c.read(listenProvider(languages)).captions.single;
      expect(caption.original, 'こんにちは');
      expect(caption.translation, '[vi] こんにちは');
      expect(fakes.recognizer.hints, ['ja']);
    },
  );

  test('a slow translation does not hold back the next caption', () async {
    fakes.recognizer.texts.addAll(['一', '二']);
    fakes.standard.gate = Completer<void>();
    final c = await build();
    await notifier(c).start();

    await speak();
    await speak();

    var captions = c.read(listenProvider(languages)).captions;
    expect(captions.map((c) => c.original), ['一', '二']);
    expect(captions.map((c) => c.status), [
      CaptionStatus.translating,
      CaptionStatus.translating,
    ]);

    fakes.standard.gate!.complete();
    await pumpEventQueue();

    captions = c.read(listenProvider(languages)).captions;
    expect(captions.map((c) => c.translation), ['[vi] 一', '[vi] 二']);
  });

  test('a 20 s monologue is cut and captions keep flowing (AC-03.4)', () async {
    fakes.recognizer.texts.addAll(['part one', 'part two']);
    final c = await build();

    await notifier(c).start();
    await speak(ms: 20000);

    final captions = c.read(listenProvider(languages)).captions;
    expect(captions.map((c) => c.original), ['part one', 'part two']);
  });

  test(
    'pausing turns the mic off and nothing is heard or saved (AC-03.6)',
    () async {
      fakes.recognizer.texts.addAll(['one', 'two']);
      final c = await build();
      await notifier(c).start();
      await notifier(c).pause();

      final state = c.read(listenProvider(languages));
      expect(state.listening, isFalse);
      expect(state.paused, isTrue);
      expect(fakes.capture.controller, isNull);

      await speak();
      expect(c.read(listenProvider(languages)).captions, isEmpty);
      expect(await fakes.sessions.watchSessions().first, isEmpty);

      await notifier(c).start();
      await speak();
      expect(
        c.read(listenProvider(languages)).captions.map((c) => c.original),
        ['one'],
      );
    },
  );

  test('Auto detects the speaker among the partner languages', () async {
    const auto = LanguagePair(listenAutoSource, 'vi');
    fakes.recognizer
      ..texts.add('Hello')
      ..detections.add('en');
    final c = await build(auto);

    expect(notifier(c, auto).autoCandidates, ['ja', 'en']);
    await notifier(c, auto).start();
    await speak();

    final caption = c.read(listenProvider(auto)).captions.single;
    expect(caption.from, 'en');
    expect(fakes.recognizer.hints, ['en']);
  });

  test('a new source language applies to the next captions', () async {
    fakes.recognizer.texts.addAll(['one', 'two']);
    final c = await build();
    await notifier(c).start();
    await speak();
    notifier(c).setSource('en');
    await speak();

    expect(fakes.recognizer.hints, ['ja', 'en']);
    expect(c.read(listenProvider(languages)).source, 'en');
  });

  test('no engine pauses translation and keeps the text', () async {
    fakes.recognizer.texts.add('こんにちは');
    final c = await build();
    c
        .read(fakeSelectionProvider.notifier)
        .set(const EngineSelection(engine: null, blocked: {}));
    await pumpEventQueue();

    await notifier(c).start();
    await speak();

    final state = c.read(listenProvider(languages));
    expect(state.block, ListenBlock.noEngine);
    expect(state.captions.single.status, CaptionStatus.paused);
  });

  test('on Standard, captions run on Gemini without a speech model', () async {
    fakes
      ..hasRecognizer = false
      ..speech = GeminiSpeechTranslator(
        ({required system, required wav, required user}) async =>
            '{"lang": "ja", "original": "こんにちは", "translation": "Xin chào"}',
      );
    final c = await build();
    await notifier(c).start();

    await speak();

    final state = c.read(listenProvider(languages));
    expect(state.block, isNull);
    expect(state.captions.single.translation, 'Xin chào');
  });

  test('no speech model blocks Start', () async {
    fakes.hasRecognizer = false;
    final c = await build();
    await notifier(c).start();

    final state = c.read(listenProvider(languages));
    expect(state.block, ListenBlock.noSpeechModel);
    expect(state.listening, isFalse);
  });

  test('leaving saves a listen session with its captions', () async {
    fakes.recognizer.texts.add('こんにちは');
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        listenClockProvider.overrideWithValue(() => fakes.nowMs),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(listenProvider(languages), (_, _) {});
    await pumpEventQueue();
    await notifier(c).start();
    await speak();

    sub.close();
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final sessions = await fakes.sessions.watchSessions().first;
    expect(sessions.single.session.mode, 'listen');
    final detail = (await fakes.sessions.load(sessions.single.session.id))!;
    expect(detail.utterances.single.targetText, '[vi] こんにちは');
    expect(detail.utterances.single.speaker, isNull);
    expect(detail.utterances.single.engine, EngineKind.standard.name);
  });
}

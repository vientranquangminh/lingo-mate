import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/features/conversation/data/model/conversation_models.dart';
import 'package:lingo_mate/features/conversation/data/notifier/conversation_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import 'conversation_fakes.dart';

void main() {
  const pair = LanguagePair('vi', 'en');
  late ConversationFakes fakes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    addTearDown(fakes.db.close);
  });

  /// Builds a container that keeps the conversation alive.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(overrides: fakes.overrides());
    addTearDown(c.dispose);
    c.listen(conversationProvider(pair), (_, _) {});
    await pumpEventQueue();
    return c;
  }

  ConversationNotifier notifier(ProviderContainer c) =>
      c.read(conversationProvider(pair).notifier);

  /// Speaks one utterance into the open mic: 1 s of speech, then silence; [later] first moves the clock past the echo tail.
  Future<void> speak({bool later = true}) async {
    if (later) {
      fakes.nowMs += 1000;
    }
    fakes.capture
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await pumpEventQueue();
  }

  test('opens on the selected engine with tap-to-talk idle', () async {
    final c = await build();
    final state = c.read(conversationProvider(pair));

    expect(state.engine, EngineKind.standard);
    expect(state.listening, isNull);
    expect(state.speakOn, isTrue);
  });

  test(
    'a tap, speech and 500 ms of silence give a translated turn (AC-02.2)',
    () async {
      fakes.recognizer.texts.add('Xin chào');
      final c = await build();

      await notifier(c).toggleMic(Speaker.a);
      expect(c.read(conversationProvider(pair)).listening, Speaker.a);
      await speak();

      final state = c.read(conversationProvider(pair));
      expect(state.listening, isNull);
      expect(fakes.recognizer.hints, ['vi']);
      final turn = state.lastBy(Speaker.a)!;
      expect(turn.original, 'Xin chào');
      expect(turn.translation, '[en] Xin chào');
      expect(turn.engine, EngineKind.standard);
      expect(turn.status, TurnStatus.translated);
      expect(fakes.tts.spoken, [('[en] Xin chào', 'en')]);
    },
  );

  test('shows the words heard so far while the mic is open', () async {
    fakes.recognizer
      ..supportsPartials = true
      ..texts.addAll(['Xin', 'Xin chào']);
    final c = await build();
    await notifier(c).toggleMic(Speaker.a);

    fakes.capture.add(pcm(1200, amplitude: 4000));
    await pumpEventQueue();
    expect(c.read(conversationProvider(pair)).draft, 'Xin');

    fakes.capture.add(pcm(700));
    await pumpEventQueue();

    final state = c.read(conversationProvider(pair));
    expect(state.draft, isNull);
    expect(state.lastBy(Speaker.a)?.original, 'Xin chào');
  });

  test('the partner side speaks B and is translated into A', () async {
    fakes.recognizer.texts.add('Hello');
    final c = await build();

    await notifier(c).toggleMic(Speaker.b);
    await speak();

    final turn = c.read(conversationProvider(pair)).lastBy(Speaker.b)!;
    expect(fakes.recognizer.hints, ['en']);
    expect(turn.translation, '[vi] Hello');
    expect(fakes.tts.spoken.single.$2, 'vi');
  });

  test('a second tap on the same side stops listening', () async {
    final c = await build();

    await notifier(c).toggleMic(Speaker.a);
    await notifier(c).toggleMic(Speaker.a);

    expect(c.read(conversationProvider(pair)).listening, isNull);
    expect(fakes.capture.controller, isNull);
  });

  test('sends the last three lines as context', () async {
    fakes.recognizer.texts.addAll(['1', '2', '3', '4', '5']);
    final c = await build();
    for (var i = 0; i < 5; i++) {
      await notifier(c).toggleMic(Speaker.a);
      await speak();
    }

    expect(fakes.standard.requests.last.context, ['2', '3', '4']);
  });

  test(
    'the mic stays gated while TTS speaks and for 150 ms after (AC-02.4)',
    () async {
      fakes.recognizer.texts.addAll(['Một', 'Hai']);
      fakes.tts.hold = true;
      final c = await build();

      await notifier(c).toggleMic(Speaker.a);
      await speak();
      expect(c.read(conversationProvider(pair)).speaking, isTrue);

      await notifier(c).toggleMic(Speaker.b);
      expect(fakes.tts.stops, 1);
      await speak(later: false);
      expect(c.read(conversationProvider(pair)).turns, hasLength(1));

      fakes.nowMs += 200;
      await speak(later: false);
      expect(c.read(conversationProvider(pair)).turns, hasLength(2));
    },
  );

  test('speak off keeps translations silent', () async {
    fakes.recognizer.texts.add('Xin chào');
    final c = await build();

    await notifier(c).setSpeakOn(false);
    await notifier(c).toggleMic(Speaker.a);
    await speak();

    expect(fakes.tts.spoken, isEmpty);
    expect(
      c.read(conversationProvider(pair)).lastBy(Speaker.a)!.translation,
      '[en] Xin chào',
    );
  });

  test(
    'a failed Standard request falls back to Offline for that line',
    () async {
      fakes.recognizer.texts.add('Xin chào');
      fakes.standard.fail = true;
      final c = await build();

      await notifier(c).toggleMic(Speaker.a);
      await speak();

      final turn = c.read(conversationProvider(pair)).lastBy(Speaker.a)!;
      expect(turn.engine, EngineKind.offline);
      expect(turn.fallback, isTrue);
      expect(turn.translation, '[en] Xin chào');
    },
  );

  test('marks the line failed when no fallback is possible', () async {
    fakes.recognizer.texts.add('Xin chào');
    fakes.standard.fail = true;
    fakes.offline.available = false;
    final c = await build();

    await notifier(c).toggleMic(Speaker.a);
    await speak();

    final turn = c.read(conversationProvider(pair)).lastBy(Speaker.a)!;
    expect(turn.status, TurnStatus.failed);
    expect(fakes.tts.spoken, isEmpty);
  });

  test(
    'an engine change mid-session raises the switched notice (AC-02.7)',
    () async {
      final c = await build();

      c
          .read(fakeSelectionProvider.notifier)
          .set(
            const EngineSelection(
              engine: EngineKind.offline,
              blocked: {EngineKind.standard: EngineBlock.noInternet},
            ),
          );
      await pumpEventQueue();

      final state = c.read(conversationProvider(pair));
      expect(state.engine, EngineKind.offline);
      expect(state.switchedTo, EngineKind.offline);
      expect(state.switchCount, 1);
      expect(state.blocked, {EngineKind.standard: EngineBlock.noInternet});
    },
  );

  test(
    'without an engine the text is kept and translation pauses (AC-02.8)',
    () async {
      fakes.recognizer.texts.add('Xin chào');
      final c = await build();
      c
          .read(fakeSelectionProvider.notifier)
          .set(
            const EngineSelection(
              engine: null,
              blocked: {
                EngineKind.standard: EngineBlock.noInternet,
                EngineKind.offline: EngineBlock.packsMissing,
              },
            ),
          );
      await pumpEventQueue();

      await notifier(c).toggleMic(Speaker.a);
      await speak();

      final state = c.read(conversationProvider(pair));
      expect(state.paused, PauseReason.noEngine);
      expect(state.lastBy(Speaker.a)!.original, 'Xin chào');
      expect(state.lastBy(Speaker.a)!.status, TurnStatus.paused);

      c
          .read(fakeSelectionProvider.notifier)
          .set(const EngineSelection(engine: EngineKind.offline, blocked: {}));
      await pumpEventQueue();
      expect(c.read(conversationProvider(pair)).paused, isNull);
    },
  );

  test(
    'Live is used when picked, and skipping it falls back to Standard',
    () async {
      final c = await build();

      c
          .read(fakeSelectionProvider.notifier)
          .set(const EngineSelection(engine: EngineKind.live, blocked: {}));
      await pumpEventQueue();
      expect(c.read(conversationProvider(pair)).engine, EngineKind.live);

      notifier(c).skipLive();
      expect(c.read(conversationProvider(pair)).engine, EngineKind.standard);
    },
  );

  test('pauses with a hint when no speech model is installed', () async {
    fakes.hasRecognizer = false;
    final c = await build();

    await notifier(c).toggleMic(Speaker.a);

    final state = c.read(conversationProvider(pair));
    expect(state.paused, PauseReason.noSpeechModel);
    expect(state.listening, isNull);
  });

  test('says so when the microphone permission is denied', () async {
    fakes.capture = FakeCapture(permitted: false);
    final c = await build();

    await notifier(c).toggleMic(Speaker.a);

    expect(c.read(conversationProvider(pair)).paused, PauseReason.micDenied);
  });

  test('a Standard failure counts toward the error burst', () async {
    fakes.recognizer.texts.addAll(['1', '2', '3']);
    fakes.standard.fail = true;
    final c = await build();
    for (var i = 0; i < 3; i++) {
      await notifier(c).toggleMic(Speaker.a);
      await speak();
    }

    expect(c.read(errorBurstProvider).isFailing(DateTime.now()), isTrue);
  });

  group('auto mode (AC-02.5)', () {
    test(
      'assigns each utterance to the side whose language was heard',
      () async {
        fakes.recognizer
          ..texts.addAll(['Hello', 'Xin chào'])
          ..detections.addAll(['en', 'vi']);
        final c = await build();

        await notifier(c).toggleAuto();
        expect(c.read(conversationProvider(pair)).auto, isTrue);
        await speak();
        await speak();

        final state = c.read(conversationProvider(pair));
        expect(state.turns.map((t) => t.speaker), [Speaker.b, Speaker.a]);
        expect(fakes.recognizer.hints, ['en', 'vi']);
        expect(state.lastBy(Speaker.b)!.translation, '[vi] Hello');
        expect(state.auto, isTrue);
        expect(fakes.capture.controller, isNotNull);
      },
    );

    test(
      'an unclear language goes to the person who did not speak last',
      () async {
        fakes.recognizer
          ..texts.addAll(['Xin chào', 'Hi'])
          ..detections.addAll(['vi', 'ja']);
        final c = await build();

        await notifier(c).toggleAuto();
        await speak();
        await speak();

        expect(c.read(conversationProvider(pair)).turns.map((t) => t.speaker), [
          Speaker.a,
          Speaker.b,
        ]);
      },
    );

    test('tapping auto again closes the mic', () async {
      final c = await build();

      await notifier(c).toggleAuto();
      await notifier(c).toggleAuto();

      expect(c.read(conversationProvider(pair)).auto, isFalse);
      expect(fakes.capture.controller, isNull);
    });

    test('a side mic tap leaves auto for tap-to-talk', () async {
      final c = await build();

      await notifier(c).toggleAuto();
      await notifier(c).toggleMic(Speaker.b);

      final state = c.read(conversationProvider(pair));
      expect(state.auto, isFalse);
      expect(state.listening, Speaker.b);
    });

    test('TTS output is not heard back while auto listens (AC-02.4)', () async {
      fakes.recognizer
        ..texts.addAll(['Xin chào', 'echo'])
        ..detections.addAll(['vi', 'en']);
      fakes.tts.hold = true;
      final c = await build();

      await notifier(c).toggleAuto();
      await speak();
      expect(c.read(conversationProvider(pair)).speaking, isTrue);

      await speak();
      expect(c.read(conversationProvider(pair)).turns, hasLength(1));
      fakes.tts.finish();
    });
  });

  group('saving (AC-02.10)', () {
    test('leaving saves the session with its lines and engines', () async {
      fakes.recognizer.texts.addAll(['Xin chào', 'Hello']);
      final c = ProviderContainer(overrides: fakes.overrides());
      addTearDown(c.dispose);
      final sub = c.listen(conversationProvider(pair), (_, _) {});
      await pumpEventQueue();
      await notifier(c).toggleMic(Speaker.a);
      await speak();
      await notifier(c).toggleMic(Speaker.b);
      await speak();

      sub.close();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final sessions = await fakes.sessions.watchSessions().first;
      expect(sessions, hasLength(1));
      expect(sessions.single.session.mode, 'conversation');
      expect(sessions.single.session.title, '[en] Xin chào');
      final detail = (await fakes.sessions.load(sessions.single.session.id))!;
      expect(detail.utterances.map((u) => u.speaker), ['a', 'b']);
      expect(detail.utterances.map((u) => u.targetText), [
        '[en] Xin chào',
        '[vi] Hello',
      ]);
      expect(detail.utterances.first.engine, 'standard');
    });

    test('a line that could not be translated is kept with its text', () async {
      fakes.recognizer.texts.add('Xin chào');
      fakes.standard.fail = true;
      fakes.offline.available = false;
      final c = ProviderContainer(overrides: fakes.overrides());
      addTearDown(c.dispose);
      final sub = c.listen(conversationProvider(pair), (_, _) {});
      await pumpEventQueue();
      await notifier(c).toggleMic(Speaker.a);
      await speak();

      sub.close();
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final hits = await fakes.sessions.search('xin chao');
      expect(hits.single.utterance.targetText, '');
      expect(hits.single.utterance.engine, 'none');
    });

    test('a session where nobody spoke is not saved', () async {
      final c = ProviderContainer(overrides: fakes.overrides());
      addTearDown(c.dispose);
      final sub = c.listen(conversationProvider(pair), (_, _) {});
      await pumpEventQueue();

      sub.close();
      await pumpEventQueue();

      expect(await fakes.db.select(fakes.db.sessions).get(), isEmpty);
    });
  });

  test('a session writes no audio or other files (AC-07.6)', () async {
    final created = <String>[];
    fakes.recognizer.texts.add('Xin chào');
    await IOOverrides.runZoned(
      () async {
        final c = ProviderContainer(overrides: fakes.overrides());
        final sub = c.listen(conversationProvider(pair), (_, _) {});
        await pumpEventQueue();
        await notifier(c).toggleMic(Speaker.a);
        await speak();
        sub.close();
        await pumpEventQueue();
        c.dispose();
      },
      createFile: (path) {
        created.add(path);
        throw FileSystemException('no files in tests', path);
      },
    );

    expect(created, isEmpty);
    expect(await fakes.sessions.search('xin chao'), hasLength(1));
  });

  test(
    'starts on an engine that was already selected, as when opened from Home',
    () async {
      fakes.recognizer.texts.add('Xin chào');
      final c = ProviderContainer(overrides: fakes.overrides());
      addTearDown(c.dispose);
      await c.read(
        engineSelectionProvider(
          const EngineRequest(mode: SessionMode.conversation, pair: pair),
        ).future,
      );
      c.listen(conversationProvider(pair), (_, _) {});

      expect(c.read(conversationProvider(pair)).engine, EngineKind.standard);
      await notifier(c).toggleMic(Speaker.a);
      await speak();
      expect(
        c.read(conversationProvider(pair)).lastBy(Speaker.a)!.translation,
        '[en] Xin chào',
      );
    },
  );
}

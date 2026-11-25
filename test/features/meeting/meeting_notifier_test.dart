import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/background/background_capture.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/features/meeting/data/model/meeting_models.dart';
import 'package:lingo_mate/features/meeting/data/notifier/meeting_notifier.dart';
import 'package:lingo_mate/features/meeting/data/notifier/meeting_setup_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../conversation/conversation_fakes.dart';
import 'meeting_fakes.dart';

void main() {
  late ConversationFakes fakes;
  late FakeBackground background;
  late bool notificationAsked;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['en'],
      'app_locale': 'en',
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    background = FakeBackground();
    notificationAsked = false;
    addTearDown(fakes.db.close);
  });

  /// Builds a container with Meeting kept alive.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        meetingClockProvider.overrideWithValue(() => fakes.nowMs),
        backgroundCaptureProvider.overrideWithValue(background),
        notificationPermissionProvider.overrideWithValue(
          () async => notificationAsked = true,
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(meetingProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  MeetingNotifier notifier(ProviderContainer c) =>
      c.read(meetingProvider.notifier);

  /// Speaks [ms] of speech, then [silenceMs] of silence.
  Future<void> speak({int ms = 1000, int silenceMs = 700}) async {
    fakes.nowMs += ms + silenceMs;
    fakes.capture
      ..add(pcm(ms, amplitude: 4000))
      ..add(pcm(silenceMs));
    await pumpEventQueue();
  }

  test('defaults to the partner language into the user language', () async {
    final c = await build();
    final state = c.read(meetingProvider);
    expect(state.source, 'en');
    expect(state.target, 'vi');
    expect(state.engine, EngineKind.standard);
  });

  test('shows the words heard so far until the line is ready', () async {
    fakes.recognizer
      ..supportsPartials = true
      ..texts.addAll(['so we can', 'so we can ship by Friday']);
    final c = await build();
    await notifier(c).start(overlay: false);

    fakes.capture.add(pcm(1200, amplitude: 4000));
    await pumpEventQueue();
    expect(c.read(meetingProvider).draft, 'so we can');

    fakes.capture.add(pcm(700));
    await pumpEventQueue();

    final state = c.read(meetingProvider);
    expect(state.draft, isNull);
    expect(state.lines.single.original, 'so we can ship by Friday');
  });

  test(
    'Start runs the service, the overlay and captions (AC-04.3, AC-04.4)',
    () async {
      fakes.recognizer.texts.addAll(['so we can ship by Friday', 'thanks']);
      final c = await build();

      await notifier(c).start(overlay: true);
      expect(notificationAsked, isTrue);
      expect(background.serviceRunning, isTrue);
      expect(background.overlayVisible, isTrue);

      await speak();
      await speak();

      final state = c.read(meetingProvider);
      expect(state.running, isTrue);
      expect(state.overlayShown, isTrue);
      expect(state.lines.map((l) => l.translation), [
        '[vi] so we can ship by Friday',
        '[vi] thanks',
      ]);
      expect(fakes.recognizer.hints, ['en', 'en']);
      expect(background.overlayLines.map((l) => l.translation), [
        '[vi] so we can ship by Friday',
        '[vi] thanks',
      ]);
      expect(
        background.overlayLines.first.original,
        'so we can ship by Friday',
      );
      expect(background.overlayEngine, 'standard');
      expect(background.overlayEngineLabel, 'Standard');
    },
  );

  test('the overlay gets at most the last 8 lines', () async {
    fakes.recognizer.texts.addAll([for (var i = 0; i < 10; i++) 'line $i']);
    final c = await build();
    await notifier(c).start(overlay: true);
    for (var i = 0; i < 10; i++) {
      await speak();
    }
    expect(background.overlayLines, hasLength(8));
    expect(background.overlayLines.last.original, 'line 9');
    expect(c.read(meetingProvider).lines, hasLength(10));
  });

  test(
    'without overlay permission captions stay in the app (AC-04.2)',
    () async {
      background.overlayAllowed = false;
      final c = await build();
      await notifier(c).start(overlay: false);

      final state = c.read(meetingProvider);
      expect(state.running, isTrue);
      expect(state.overlayShown, isFalse);
      expect(state.inAppOnly, isTrue);
      expect(background.serviceRunning, isTrue);
    },
  );

  test('a long pause marks a new speaker turn', () async {
    fakes.recognizer.texts.addAll(['one', 'two', 'three']);
    final c = await build();
    await notifier(c).start(overlay: true);
    await speak();
    await speak(silenceMs: 3500);
    await speak();

    final lines = c.read(meetingProvider).lines;
    expect(lines.map((l) => l.newTurn), [false, false, true]);
  });

  test(
    'a long-pressed overlay line is saved to the phrasebook (AC-04.5)',
    () async {
      fakes.recognizer.texts.addAll(['first', 'second']);
      final c = await build();
      await notifier(c).start(overlay: true);
      await speak();
      await speak();

      background.controller.add(
        const OverlayLineLongPressed('[vi] first', index: 0),
      );
      await pumpEventQueue();

      final phrases = await PhraseRepository(fakes.db)
          .watch(const PhraseFilter())
          .first;
      expect(phrases.single.phrase.sourceText, 'first');
      expect(phrases.single.phrase.targetText, '[vi] first');
      expect(c.read(meetingProvider).savedCount, 1);
    },
  );

  test(
    'Stop from the notification stops everything and saves (AC-04.8)',
    () async {
      fakes.recognizer.texts.add('hello team');
      final c = await build();
      await notifier(c).start(overlay: true);
      await speak();

      background.controller.add(const BackgroundStopPressed());
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = c.read(meetingProvider);
      expect(state.running, isFalse);
      expect(background.serviceRunning, isFalse);
      expect(background.overlayVisible, isFalse);
      expect(fakes.capture.controller, isNull);
      expect(state.lines, hasLength(1));
      final sessions = await fakes.sessions.watchSessions().first;
      expect(sessions.single.session.mode, 'meeting');
      expect(sessions.single.session.endedAt, isNotNull);
    },
  );

  test('the overlay can be hidden and shown again while running', () async {
    final c = await build();
    await notifier(c).start(overlay: true);
    await notifier(c).setOverlay(false);
    expect(background.overlayVisible, isFalse);
    expect(c.read(meetingProvider).overlayShown, isFalse);
    await notifier(c).setOverlay(true);
    expect(background.overlayVisible, isTrue);
  });

  test('no engine pauses translation and keeps the text', () async {
    fakes.recognizer.texts.add('hello');
    final c = await build();
    c
        .read(fakeSelectionProvider.notifier)
        .set(const EngineSelection(engine: null, blocked: {}));
    await pumpEventQueue();
    await notifier(c).start(overlay: true);
    await speak();

    final state = c.read(meetingProvider);
    expect(state.block, MeetingBlock.noEngine);
    expect(state.lines.single.status, MeetingLineStatus.paused);
    expect(background.overlayLines.single.translation, 'hello');
  });

  test('no speech model blocks Start without starting the service', () async {
    fakes.hasRecognizer = false;
    final c = await build();
    await notifier(c).start(overlay: true);

    expect(c.read(meetingProvider).block, MeetingBlock.noSpeechModel);
    expect(background.serviceRunning, isFalse);
  });

  test('the setup card choice is saved (AC-04.1)', () async {
    final c = await build();
    expect(c.read(meetingSetupDismissedProvider), isFalse);
    await c.read(meetingSetupDismissedProvider.notifier).dismiss();
    expect(c.read(meetingSetupDismissedProvider), isTrue);
    expect(fakes.prefs.getBool('meeting_setup_dismissed'), isTrue);
  });
}

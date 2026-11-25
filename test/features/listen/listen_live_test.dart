import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/engines/engine_instances.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/live/live_access.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/features/listen/data/model/listen_models.dart';
import 'package:lingo_mate/features/listen/data/notifier/listen_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../../core/engines/live/live_fakes.dart';
import '../conversation/conversation_fakes.dart';

void main() {
  const languages = LanguagePair('en', 'vi');
  late ConversationFakes fakes;
  late FakeLiveAccess access;
  late List<FakeLiveSession> sessions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    addTearDown(fakes.db.close);
    access = FakeLiveAccess();
    sessions = [];
  });

  /// Builds a container where the selector picks Live.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        listenClockProvider.overrideWithValue(() => fakes.nowMs),
        liveAccessProvider.overrideWithValue(access),
        liveSessionOpenerProvider.overrideWithValue((config) {
          final session = FakeLiveSession(config);
          sessions.add(session);
          return session;
        }),
        engineRemoteConfigProvider.overrideWithValue(
          RemoteConfigService.withDefaults(CrashReporter.disabled()),
        ),
      ],
    );
    addTearDown(c.dispose);
    c
      ..read(fakeSelectionProvider.notifier)
          .set(const EngineSelection(engine: EngineKind.live, blocked: {}))
      ..listen(listenProvider(languages), (_, _) {});
    await pumpEventQueue();
    return c;
  }

  test(
    'with Live, captions come from the Live transcripts and are saved (F-05)',
    () async {
      access.grants.add(
        const LiveGrant.allowed(credentials: LiveApiKey('k'), blockSec: 600),
      );
      final c = await build();
      final notifier = c.read(listenProvider(languages).notifier);
      expect(c.read(listenProvider(languages)).engine, EngineKind.live);

      await notifier.start();
      expect(sessions.single.config.targetLanguage, 'vi');
      fakes.capture.add(pcm(300, amplitude: 4000));
      await pumpEventQueue();
      expect(sessions.single.sent, isNotEmpty);

      sessions.single
        ..emit(const LiveInputTranscript('Good morning'))
        ..emit(const LiveOutputTranscript('Chào buổi sáng'));
      await pumpEventQueue();
      var caption = c.read(listenProvider(languages)).captions.single;
      expect(caption.status, CaptionStatus.translating);
      expect(caption.engine, EngineKind.live);

      sessions.single.emit(const LiveTurnComplete());
      await pumpEventQueue();
      caption = c.read(listenProvider(languages)).captions.single;
      expect(caption.translation, 'Chào buổi sáng');
      expect(caption.status, CaptionStatus.translated);
      expect(fakes.recognizer.hints, isEmpty);

      await notifier.pause();
      await pumpEventQueue();
      final rows = await fakes.db.select(fakes.db.utterances).get();
      expect(rows.single.engine, 'live');
    },
  );

  test(
    'when Live is refused for quota, Listen carries on with Standard (AC-14.2)',
    () async {
      access.grants.add(const LiveGrant.denied(LiveDenial.quota));
      fakes.recognizer.texts.add('hello');
      final c = await build();
      final notifier = c.read(listenProvider(languages).notifier);

      await notifier.start();
      final state = c.read(listenProvider(languages));
      expect(state.engine, EngineKind.standard);
      expect(state.liveDenial, LiveDenial.quota);
      expect(state.liveStops, 1);
      expect(state.listening, isTrue);

      fakes.nowMs += 1700;
      fakes.capture
        ..add(pcm(1000, amplitude: 4000))
        ..add(pcm(700));
      await pumpEventQueue();
      expect(
        c.read(listenProvider(languages)).captions.single.translation,
        '[vi] hello',
      );
      await notifier.pause();
    },
  );

  test(
    'a dropped Live connection falls back to Standard mid-session',
    () async {
      access.grants.add(
        const LiveGrant.allowed(credentials: LiveApiKey('k'), blockSec: 600),
      );
      final c = await build();
      final notifier = c.read(listenProvider(languages).notifier);
      await notifier.start();

      sessions.single.emit(const LiveClosed(code: 1011));
      await pumpEventQueue();

      final state = c.read(listenProvider(languages));
      expect(state.engine, EngineKind.standard);
      expect(state.liveStops, 1);
      expect(state.listening, isTrue);
      await notifier.pause();
    },
  );

  test('skipping Live uses the text engines (AC-13.6)', () async {
    final c = await build();
    c.read(listenProvider(languages).notifier).skipLive();

    expect(c.read(listenProvider(languages)).engine, EngineKind.standard);
    expect(access.requests, 0);
  });
}

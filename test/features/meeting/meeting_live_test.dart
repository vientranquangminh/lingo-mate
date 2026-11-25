import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/background/background_capture.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/engines/engine_instances.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/live/live_access.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/features/meeting/data/model/meeting_models.dart';
import 'package:lingo_mate/features/meeting/data/notifier/meeting_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../../core/engines/live/live_fakes.dart';
import '../conversation/conversation_fakes.dart';
import 'meeting_fakes.dart';

void main() {
  late ConversationFakes fakes;
  late FakeBackground background;
  late FakeLiveAccess access;
  late List<FakeLiveSession> sessions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['en'],
      'app_locale': 'en',
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    background = FakeBackground();
    access = FakeLiveAccess();
    sessions = [];
    addTearDown(fakes.db.close);
  });

  /// Builds a container where the selector picks Live.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        meetingClockProvider.overrideWithValue(() => fakes.nowMs),
        backgroundCaptureProvider.overrideWithValue(background),
        notificationPermissionProvider.overrideWithValue(() async {}),
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
      ..listen(meetingProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  test('Meeting on Live shows Live lines, pushes them to the overlay and saves them', () async {
    access.grants.add(
      const LiveGrant.allowed(credentials: LiveApiKey('k'), blockSec: 600),
    );
    final c = await build();
    final notifier = c.read(meetingProvider.notifier);
    expect(c.read(meetingProvider).engine, EngineKind.live);

    await notifier.start(overlay: true);
    expect(sessions.single.config.targetLanguage, 'vi');
    sessions.single
      ..emit(const LiveInputTranscript('Ship it Friday'))
      ..emit(const LiveOutputTranscript('Phát hành thứ Sáu'))
      ..emit(const LiveTurnComplete());
    await pumpEventQueue();

    final line = c.read(meetingProvider).lines.single;
    expect(line.translation, 'Phát hành thứ Sáu');
    expect(line.status, MeetingLineStatus.translated);
    expect(background.overlayLines.last.translation, 'Phát hành thứ Sáu');

    await notifier.stop();
    final rows = await fakes.db.select(fakes.db.utterances).get();
    expect(rows.single.engine, 'live');
    expect(sessions.single.closed, isTrue);
  });

  test(
    'a refused Live grant falls back to on-device captions (AC-14.2)',
    () async {
      access.grants.add(const LiveGrant.denied(LiveDenial.unavailable));
      fakes.recognizer.texts.add('hello');
      final c = await build();
      final notifier = c.read(meetingProvider.notifier);

      await notifier.start(overlay: false);
      expect(c.read(meetingProvider).engine, EngineKind.standard);
      expect(c.read(meetingProvider).liveStops, 1);

      fakes.nowMs += 1700;
      fakes.capture
        ..add(pcm(1000, amplitude: 4000))
        ..add(pcm(700));
      await pumpEventQueue();
      expect(c.read(meetingProvider).lines.single.translation, '[vi] hello');
      await notifier.stop();
    },
  );
}

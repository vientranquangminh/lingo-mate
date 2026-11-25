import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/pcm_player.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/engines/engine_instances.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/live/live_access.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/features/conversation/data/model/conversation_models.dart';
import 'package:lingo_mate/features/conversation/data/notifier/conversation_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../../core/engines/live/live_fakes.dart';
import 'conversation_fakes.dart';

/// Records the speech written to the player.
class _FakePlayer implements PcmPlayer {
  final written = <int>[];
  bool started = false;

  @override
  Future<void> start({int sampleRate = 24000}) async => started = true;

  @override
  Future<void> write(Uint8List bytes) async => written.add(bytes.length);

  @override
  Future<void> stop() async => started = false;
}

void main() {
  const pair = LanguagePair('vi', 'en');
  late ConversationFakes fakes;
  late FakeLiveAccess access;
  late List<FakeLiveSession> sessions;
  late _FakePlayer player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    addTearDown(fakes.db.close);
    access = FakeLiveAccess();
    sessions = [];
    player = _FakePlayer();
  });

  /// Builds a container where the selector picks Live.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        liveAccessProvider.overrideWithValue(access),
        liveSessionOpenerProvider.overrideWithValue((config) {
          final session = FakeLiveSession(config);
          sessions.add(session);
          return session;
        }),
        livePlayerProvider.overrideWithValue(player),
        engineRemoteConfigProvider.overrideWithValue(
          RemoteConfigService.withDefaults(CrashReporter.disabled()),
        ),
      ],
    );
    addTearDown(c.dispose);
    c
      ..read(fakeSelectionProvider.notifier)
          .set(const EngineSelection(engine: EngineKind.live, blocked: {}))
      ..listen(conversationProvider(pair), (_, _) {});
    await pumpEventQueue();
    return c;
  }

  LiveGrant grant() =>
      const LiveGrant.allowed(credentials: LiveApiKey('k'), blockSec: 600);

  test('Live opens one session into each language and translates both sides as they talk', () async {
    access.grants.addAll([grant(), grant()]);
    final c = await build();
    final notifier = c.read(conversationProvider(pair).notifier);
    expect(c.read(conversationProvider(pair)).engine, EngineKind.live);

    await notifier.toggleMic(Speaker.a);
    final state = c.read(conversationProvider(pair));
    expect(state.liveListening, isTrue);
    expect(sessions.map((s) => s.config.targetLanguage), ['en', 'vi']);
    expect(player.started, isTrue);

    fakes.capture.add(pcm(300, amplitude: 4000));
    await pumpEventQueue();
    expect(sessions.every((s) => s.sent.isNotEmpty), isTrue);

    sessions[1].emit(const LiveInputTranscript('Xin chào'));
    sessions[0]
      ..emit(const LiveInputTranscript('Xin chào'))
      ..emit(const LiveOutputTranscript('Hello'))
      ..emit(LiveOutputAudio(Uint8List(4800)))
      ..emit(const LiveTurnComplete());
    sessions[1].emit(const LiveTurnComplete());
    await pumpEventQueue();

    final turn = c.read(conversationProvider(pair)).turns.single;
    expect(turn.speaker, Speaker.a);
    expect(turn.original, 'Xin chào');
    expect(turn.translation, 'Hello');
    expect(turn.status, TurnStatus.translated);
    expect(player.written, [4800]);
    expect(c.read(conversationProvider(pair)).speaking, isTrue);

    sessions[1]
      ..emit(const LiveInputTranscript('Nice to meet you'))
      ..emit(const LiveOutputTranscript('Rất vui được gặp bạn'))
      ..emit(const LiveTurnComplete());
    await pumpEventQueue();
    expect(c.read(conversationProvider(pair)).turns.last.speaker, Speaker.b);

    await notifier.toggleAuto();
    expect(c.read(conversationProvider(pair)).liveListening, isFalse);
    expect(sessions.every((s) => s.closed), isTrue);
    expect(player.started, isFalse);
  });

  test('with speech off, Live captions only', () async {
    access.grants.addAll([grant(), grant()]);
    final c = await build();
    final notifier = c.read(conversationProvider(pair).notifier);
    await notifier.setSpeakOn(false);
    await notifier.toggleMic(Speaker.a);

    sessions[0]
      ..emit(const LiveOutputTranscript('Hello'))
      ..emit(LiveOutputAudio(Uint8List(4800)));
    await pumpEventQueue();

    expect(player.written, isEmpty);
    expect(
      c.read(conversationProvider(pair)).turns.single.translation,
      'Hello',
    );
    await notifier.toggleMic(Speaker.a);
  });

  test(
    'a refused Live grant falls back to auto mode on the text engines',
    () async {
      access.grants.add(const LiveGrant.denied(LiveDenial.unavailable));
      final c = await build();
      final notifier = c.read(conversationProvider(pair).notifier);

      await notifier.toggleMic(Speaker.a);

      final state = c.read(conversationProvider(pair));
      expect(state.engine, EngineKind.standard);
      expect(state.liveStops, 1);
      expect(state.auto, isTrue);
      expect(state.liveListening, isFalse);
      await notifier.toggleAuto();
    },
  );

  test('a dropped Live session falls back mid-conversation', () async {
    access.grants.addAll([grant(), grant()]);
    final c = await build();
    final notifier = c.read(conversationProvider(pair).notifier);
    await notifier.toggleMic(Speaker.a);

    sessions[0].emit(const LiveClosed(code: 1011));
    await pumpEventQueue();

    final state = c.read(conversationProvider(pair));
    expect(state.engine, EngineKind.standard);
    expect(state.auto, isTrue);
    expect(sessions.every((s) => s.closed), isTrue);
    await notifier.toggleAuto();
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_capture.dart';
import 'package:lingo_mate/core/audio/pcm_player.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/live/live_session.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/features/devtools/data/notifier/devtools_providers.dart';
import 'package:lingo_mate/features/devtools/data/notifier/live_test_notifier.dart';

import '../../core/audio/audio_test_utils.dart';

/// Live session driven by the test.
class _FakeLiveSession extends LiveSession {
  _FakeLiveSession(this.config) : super(config);

  final LiveSessionConfig config;
  final server = StreamController<LiveEvent>.broadcast();
  final sent = <Uint8List>[];
  bool closed = false;

  @override
  Stream<LiveEvent> get events => server.stream;

  @override
  Future<void> open() async {}

  @override
  void sendAudio(Uint8List pcm16k) => sent.add(pcm16k);

  @override
  Future<void> close() async => closed = true;
}

/// Player that records what it was asked to play.
class _FakePlayer implements PcmPlayer {
  final written = <Uint8List>[];
  bool started = false;

  @override
  Future<void> start({int sampleRate = 24000}) async => started = true;

  @override
  Future<void> write(Uint8List bytes) async => written.add(bytes);

  @override
  Future<void> stop() async => started = false;
}

/// Microphone fed by the test.
class _FakeCapture implements AudioCapture {
  final controller = StreamController<Uint8List>.broadcast();

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async =>
      controller.stream;

  @override
  Future<void> stop() async {}
}

void main() {
  late List<_FakeLiveSession> sessions;
  late _FakePlayer player;
  late _FakeCapture capture;
  late ProviderContainer container;

  /// Builds a container with fakes and the given API key.
  ProviderContainer build({String apiKey = 'dev-key'}) {
    final c = ProviderContainer(
      overrides: [
        liveApiKeyProvider.overrideWithValue(apiKey),
        pcmPlayerProvider.overrideWithValue(player),
        audioCaptureProvider.overrideWithValue(capture),
        remoteConfigProvider.overrideWithValue(
          RemoteConfigService.withDefaults(CrashReporter.disabled()),
        ),
        liveSessionFactoryProvider.overrideWithValue((config) {
          final s = _FakeLiveSession(config);
          sessions.add(s);
          return s;
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    sessions = [];
    player = _FakePlayer();
    capture = _FakeCapture();
    container = build();
  });

  test('one-way streams the mic to an English session', () async {
    await container.read(liveTestProvider.notifier).toggle();

    expect(container.read(liveTestProvider).running, isTrue);
    expect(sessions.single.config.targetLanguage, 'en');
    expect(sessions.single.config.model, 'gemini-3.5-live-translate-preview');
    expect(sessions.single.config.credentials, const LiveApiKey('dev-key'));
    expect(player.started, isTrue);

    capture.controller.add(pcm(200, amplitude: 500));
    await pumpEventQueue();

    expect(sessions.single.sent, hasLength(2));
  });

  test('two-way opens Vietnamese and English sessions', () async {
    container.read(liveTestProvider.notifier).setTwoWay(true);

    await container.read(liveTestProvider.notifier).toggle();

    expect(sessions.map((s) => s.config.targetLanguage), ['vi', 'en']);
  });

  test('records lag, transcripts and plays the translation', () async {
    await container.read(liveTestProvider.notifier).toggle();
    final session = sessions.single;

    session.server
      ..add(const LiveInputTranscript('xin '))
      ..add(const LiveInputTranscript('chào'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    session.server
      ..add(LiveOutputAudio(Uint8List(480)))
      ..add(const LiveOutputTranscript('hello'))
      ..add(const LiveTurnComplete());
    await pumpEventQueue();

    final state = container.read(liveTestProvider);
    expect(state.lagsMs.single, greaterThanOrEqualTo(30));
    expect(state.medianLagMs, state.lagsMs.single);
    expect(state.lines.single.input, 'xin chào');
    expect(state.lines.single.output, 'hello');
    expect(player.written.single.length, 480);
  });

  test('does not send the mic while the translation plays', () async {
    await container.read(liveTestProvider.notifier).toggle();
    final session = sessions.single;

    session.server.add(LiveOutputAudio(Uint8List(48000)));
    await pumpEventQueue();
    capture.controller.add(pcm(200, amplitude: 500));
    await pumpEventQueue();

    expect(session.sent, isEmpty);
  });

  test('stop closes the sessions and playback', () async {
    final notifier = container.read(liveTestProvider.notifier);
    await notifier.toggle();

    await notifier.toggle();

    expect(container.read(liveTestProvider).running, isFalse);
    expect(sessions.single.closed, isTrue);
    expect(player.started, isFalse);
  });

  test('explains a missing API key and opens nothing', () async {
    container = build(apiKey: '');

    await container.read(liveTestProvider.notifier).toggle();

    expect(container.read(liveTestProvider).error, contains('GEMINI_API_KEY'));
    expect(sessions, isEmpty);
  });
}

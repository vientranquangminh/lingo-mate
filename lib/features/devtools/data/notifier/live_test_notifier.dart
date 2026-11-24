import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/pcm_player.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/live/live_models.dart';
import '../../../../core/engines/live/live_session.dart';
import '../../../../env.dart';
import '../state/live_test_state.dart';
import 'devtools_providers.dart';

/// Opens Live sessions for the devtools Live test.
final liveSessionFactoryProvider =
    Provider<LiveSession Function(LiveSessionConfig)>((ref) => LiveSession.new);

/// Dev API key for Live (dev flavor only).
final liveApiKeyProvider = Provider<String>((ref) => Env.geminiApiKey);

/// Plays Live audio.
final pcmPlayerProvider = Provider<PcmPlayer>((ref) => const NativePcmPlayer());

/// Live test state.
final liveTestProvider = NotifierProvider<LiveTestNotifier, LiveTestState>(
  LiveTestNotifier.new,
);

/// Streams the mic to one Live session (target en) or two (vi and en, OQ-4), plays the translation and measures lag.
class LiveTestNotifier extends Notifier<LiveTestState> {
  static const _maxLines = 6;
  static const _sampleRate = 24000;

  final _sessions = <LiveSession>[];
  final _subscriptions = <StreamSubscription<Object>>[];
  AudioPipeline? _pipeline;
  PcmPlayer? _player;
  final _clock = Stopwatch()..start();
  final _turnStartMs = <String, int?>{};
  int _playbackEndsAtMs = 0;
  Timer? _gateTimer;

  @override
  LiveTestState build() {
    ref.onDispose(_stop);
    return const LiveTestState();
  }

  /// Chooses one-way (to English) or two-way (Vietnamese and English) before starting.
  void setTwoWay(bool value) {
    if (!state.running) {
      state = state.copyWith(twoWay: value);
    }
  }

  /// Starts the Live test, or stops it when running.
  Future<void> toggle() async {
    if (state.running) {
      await _stop();
      state = state.copyWith(running: false);
      return;
    }
    final apiKey = ref.read(liveApiKeyProvider);
    if (apiKey.isEmpty) {
      state = state.copyWith(error: 'GEMINI_API_KEY is not set in .env.dev');
      return;
    }
    state = state.copyWith(error: '', lines: const [], lagsMs: const []);
    final model = ref.read(remoteConfigProvider).modelLiveTranslate;
    final targets = state.twoWay ? ['vi', 'en'] : ['en'];
    final player = ref.read(pcmPlayerProvider);
    _player = player;
    final gate = EchoGate(nowMs: () => _clock.elapsedMilliseconds);
    try {
      await player.start(sampleRate: _sampleRate);
      for (final target in targets) {
        final session = ref.read(liveSessionFactoryProvider)(
          LiveSessionConfig(
            model: model,
            targetLanguage: target,
            credentials: LiveApiKey(apiKey),
          ),
        );
        _sessions.add(session);
        _subscriptions.add(
          session.events.listen((e) => _onEvent(target, e, player, gate)),
        );
        await session.open();
      }
      final pipeline = AudioPipeline(
        capture: ref.read(audioCaptureProvider),
        vad: EnergyVoiceActivityDetector(),
        echoGate: gate,
      );
      _subscriptions.add(
        pipeline.liveChunks.listen((chunk) {
          for (final s in _sessions) {
            s.sendAudio(chunk);
          }
        }),
      );
      if (!await pipeline.start()) {
        throw StateError('microphone permission denied');
      }
      _pipeline = pipeline;
      if (!ref.mounted) {
        await _stop();
        return;
      }
      state = state.copyWith(running: true);
    } catch (e) {
      await _stop();
      if (ref.mounted) {
        state = state.copyWith(running: false, error: '$e');
      }
    }
  }

  /// Updates transcripts, plays audio, gates the mic while speaking and records lag.
  void _onEvent(
    String target,
    LiveEvent event,
    PcmPlayer player,
    EchoGate gate,
  ) {
    final now = _clock.elapsedMilliseconds;
    switch (event) {
      case LiveInputTranscript(:final text):
        _turnStartMs[target] ??= now;
        _append(target, input: text);
      case LiveOutputTranscript(:final text):
        _append(target, output: text);
      case LiveOutputAudio(:final pcm24k):
        final start = _turnStartMs[target];
        if (start != null) {
          state = state.copyWith(lagsMs: [...state.lagsMs, now - start]);
          _turnStartMs[target] = null;
        }
        unawaited(player.write(pcm24k));
        _holdGate(gate, pcm24k, now);
      case LiveTurnComplete():
        _turnStartMs[target] = null;
      case LiveError(:final message):
        state = state.copyWith(error: message);
      default:
        break;
    }
  }

  /// Keeps the echo gate closed until the queued translated audio has played.
  void _holdGate(EchoGate gate, Uint8List pcm24k, int now) {
    final durationMs = pcm24k.length ~/ 2 * 1000 ~/ _sampleRate;
    _playbackEndsAtMs =
        (_playbackEndsAtMs > now ? _playbackEndsAtMs : now) + durationMs;
    gate.setSpeaking(true);
    _gateTimer?.cancel();
    _gateTimer = Timer(
      Duration(milliseconds: _playbackEndsAtMs - now),
      () => gate.setSpeaking(false),
    );
  }

  /// Adds text to the current line for [target].
  void _append(String target, {String input = '', String output = ''}) {
    final lines = [...state.lines];
    final index = lines.lastIndexWhere((l) => l.target == target);
    if (index < 0 || (input.isNotEmpty && lines[index].output.isNotEmpty)) {
      lines.add(LiveLine(target: target, input: input, output: output));
    } else {
      final line = lines[index];
      lines[index] = LiveLine(
        target: target,
        input: line.input + input,
        output: line.output + output,
      );
    }
    state = state.copyWith(
      lines: lines.length > _maxLines
          ? lines.sublist(lines.length - _maxLines)
          : lines,
    );
  }

  /// Stops the mic, the sessions and playback.
  Future<void> _stop() async {
    _gateTimer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _pipeline?.dispose();
    _pipeline = null;
    for (final s in _sessions) {
      await s.close();
    }
    _sessions.clear();
    _turnStartMs.clear();
    final player = _player;
    _player = null;
    await player?.stop().catchError((Object _) {});
  }
}

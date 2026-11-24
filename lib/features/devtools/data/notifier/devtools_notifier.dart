import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_capture.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/latency_timeline.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/engines.dart';
import '../state/devtools_state.dart';
import 'devtools_providers.dart';

/// Devtools switches and the mic test.
final devtoolsProvider = NotifierProvider<DevtoolsNotifier, DevtoolsState>(
  DevtoolsNotifier.new,
);

/// Holds devtools switches and runs the live mic test.
class DevtoolsNotifier extends Notifier<DevtoolsState> {
  static const _maxSegments = 5;
  static const _levelEveryFrames = 5;

  AudioPipeline? _pipeline;
  final _subscriptions = <StreamSubscription<Object>>[];
  int _frames = 0;

  @override
  DevtoolsState build() {
    ref.onDispose(_stopMic);
    return const DevtoolsState();
  }

  /// Forces an engine, or returns to auto-selection with null.
  void forceEngine(EngineKind? engine) =>
      state = state.copyWith(forcedEngine: () => engine);

  /// Shows or hides the latency HUD.
  void setLatencyHud(bool visible) =>
      state = state.copyWith(latencyHudVisible: visible);

  /// Makes cloud engines behave as if the region were blocked.
  void setForceRegionBlock(bool value) =>
      state = state.copyWith(forceRegionBlock: value);

  /// Switches between the voice recognition source and the raw meeting mic.
  void setRawMic(bool raw) => _setCapture(
    AudioCaptureConfig(
      source: raw ? CaptureSource.mic : CaptureSource.voiceRecognition,
      noiseSuppression: state.captureConfig.noiseSuppression,
      autoGain: state.captureConfig.autoGain,
    ),
  );

  /// Turns noise suppression on or off.
  void setNoiseSuppression(bool value) => _setCapture(
    AudioCaptureConfig(
      source: state.captureConfig.source,
      noiseSuppression: value,
      autoGain: state.captureConfig.autoGain,
    ),
  );

  /// Turns automatic gain on or off.
  void setAutoGain(bool value) => _setCapture(
    AudioCaptureConfig(
      source: state.captureConfig.source,
      noiseSuppression: state.captureConfig.noiseSuppression,
      autoGain: value,
    ),
  );

  /// Starts the mic test, or stops it when it is running.
  Future<void> toggleMic() async {
    if (state.micRunning) {
      await _stopMic();
      state = state.copyWith(micRunning: false, micLevelDbfs: () => null);
      return;
    }
    final clock = Stopwatch()..start();
    final pipeline = AudioPipeline(
      capture: ref.read(audioCaptureProvider),
      vad: EnergyVoiceActivityDetector(),
      echoGate: EchoGate(nowMs: () => clock.elapsedMilliseconds),
    );
    _subscriptions
      ..add(pipeline.levels.listen(_onLevel))
      ..add(
        pipeline.segments.listen((segment) {
          final timeline = LatencyTimeline(
            nowMs: () => clock.elapsedMilliseconds,
          )..mark(LatencyStage.vadEnd);
          ref.read(latencyLogProvider.notifier).add(timeline.toRow());
          final segments = [
            ...state.micSegments,
            MicSegment(
              durationMs: segment.durationMs,
              speechRatio: segment.speechRatio,
            ),
          ];
          state = state.copyWith(
            micSegments: segments.length > _maxSegments
                ? segments.sublist(segments.length - _maxSegments)
                : segments,
          );
        }),
      );
    final started = await pipeline.start(state.captureConfig);
    if (!started) {
      await _disposePipeline(pipeline);
      state = state.copyWith(micDenied: true);
      return;
    }
    _pipeline = pipeline;
    state = state.copyWith(micRunning: true, micDenied: false);
  }

  /// Applies a capture setting, restarting the mic test when it is running.
  Future<void> _setCapture(AudioCaptureConfig config) async {
    final wasRunning = state.micRunning;
    if (wasRunning) {
      await toggleMic();
    }
    state = state.copyWith(captureConfig: config);
    if (wasRunning) {
      await toggleMic();
    }
  }

  /// Publishes every fifth frame's level to keep rebuilds cheap.
  void _onLevel(double dbfs) {
    if (_frames++ % _levelEveryFrames == 0) {
      state = state.copyWith(micLevelDbfs: () => dbfs);
    }
  }

  /// Stops and releases the mic test pipeline.
  Future<void> _stopMic() async {
    final pipeline = _pipeline;
    _pipeline = null;
    if (pipeline != null) {
      await _disposePipeline(pipeline);
    }
  }

  /// Cancels listeners and disposes a pipeline.
  Future<void> _disposePipeline(AudioPipeline pipeline) async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await pipeline.dispose();
  }
}

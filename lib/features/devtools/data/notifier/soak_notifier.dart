import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_capture.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/background/background_capture.dart';
import '../state/soak_state.dart';
import 'devtools_providers.dart';

/// Monotonic milliseconds used to time the soak; replaced in tests.
final soakClockProvider = Provider<int Function()>((ref) {
  final watch = Stopwatch()..start();
  return () => watch.elapsedMilliseconds;
});

/// Soak test state.
final soakProvider = NotifierProvider<SoakNotifier, SoakState>(
  SoakNotifier.new,
);

/// Runs Meeting-style capture in the foreground service with the caption overlay and tracks gaps in the audio (AC-04.6).
class SoakNotifier extends Notifier<SoakState> {
  static const _tick = Duration(seconds: 1);

  AudioPipeline? _pipeline;
  BackgroundCapture? _background;
  final _subscriptions = <StreamSubscription<Object>>[];
  late int Function() _now;
  int _startMs = 0;
  int? _lastFrameMs;
  Timer? _ticker;
  final _overlayLines = <String>[];

  @override
  SoakState build() {
    ref.onDispose(_stop);
    return const SoakState();
  }

  /// Starts the soak test, or stops it when running.
  Future<void> toggle() async {
    if (state.running) {
      await _stop();
      state = state.copyWith(running: false);
      return;
    }
    final background = ref.read(backgroundCaptureProvider);
    _background = background;
    _now = ref.read(soakClockProvider);
    state = const SoakState();
    try {
      await ref.read(notificationPermissionProvider)();
      await background.startService();
      _subscriptions.add(background.events.listen(_onBackgroundEvent));
      final pipeline = AudioPipeline(
        capture: ref.read(audioCaptureProvider),
        vad: EnergyVoiceActivityDetector(),
        echoGate: EchoGate(nowMs: () => _now()),
      );
      _startMs = _now();
      _lastFrameMs = null;
      _subscriptions
        ..add(pipeline.levels.listen((_) => _onFrame()))
        ..add(
          pipeline.segments.listen((segment) {
            state = state.copyWith(segments: state.segments + 1);
            _showLine('#${state.segments} · ${segment.durationMs} ms');
          }),
        );
      if (!await pipeline.start(const AudioCaptureConfig.meeting())) {
        throw StateError('microphone permission denied');
      }
      _pipeline = pipeline;
      final overlay =
          await background.canDrawOverlays() && await background.showOverlay();
      _ticker = Timer.periodic(_tick, (_) => _onTick());
      if (!ref.mounted) {
        await _stop();
        return;
      }
      state = state.copyWith(
        running: true,
        overlayShown: overlay,
        overlayDenied: !overlay,
      );
    } catch (e) {
      await _stop();
      if (ref.mounted) {
        state = state.copyWith(running: false, error: '$e');
      }
    }
  }

  /// Opens the system overlay permission screen.
  Future<void> openOverlaySettings() =>
      ref.read(backgroundCaptureProvider).openOverlaySettings();

  /// Records the longest gap between audio frames; a gap means capture paused in the background.
  void _onFrame() {
    final now = _now();
    final last = _lastFrameMs;
    _lastFrameMs = now;
    if (last != null && now - last > state.maxGapMs) {
      state = state.copyWith(maxGapMs: now - last);
    }
  }

  /// Updates the elapsed time every second.
  void _onTick() {
    state = state.copyWith(elapsed: Duration(milliseconds: _now() - _startMs));
  }

  /// Stops on the notification's Stop, and keeps lines long-pressed in the overlay.
  void _onBackgroundEvent(BackgroundEvent event) {
    switch (event) {
      case BackgroundStopPressed():
        unawaited(
          _stop().then((_) {
            if (ref.mounted) {
              state = state.copyWith(running: false);
            }
          }),
        );
      case OverlayLineLongPressed(:final text):
        state = state.copyWith(savedLines: [...state.savedLines, text]);
    }
  }

  /// Adds a line to the overlay, keeping the last eight.
  void _showLine(String line) {
    _overlayLines.add(line);
    if (_overlayLines.length > 8) {
      _overlayLines.removeAt(0);
    }
    unawaited(
      _background?.updateOverlay([
        for (final text in _overlayLines)
          OverlayLine(original: '', translation: text),
      ]),
    );
  }

  /// Stops capture, the service and the overlay.
  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _pipeline?.dispose();
    _pipeline = null;
    final background = _background;
    _background = null;
    _overlayLines.clear();
    if (background != null) {
      await background.hideOverlay().catchError((Object _) {});
      await background.stopService().catchError((Object _) {});
    }
  }
}

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../engines/asr/asr_models.dart';
import 'audio_frame.dart';
import 'voice_activity_detector.dart';

/// Silero VAD through sherpa-onnx; reports speech per frame and leaves segmenting to [Segmenter].
class SileroVoiceActivityDetector implements VoiceActivityDetector {
  /// Loads the Silero model at [modelPath].
  factory SileroVoiceActivityDetector(String modelPath) {
    ensureBindings();
    return SileroVoiceActivityDetector._(modelPath);
  }

  SileroVoiceActivityDetector._(String modelPath)
    : _vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: modelPath,
            minSilenceDuration: 0.1,
            minSpeechDuration: 0.1,
            maxSpeechDuration: 30,
          ),
          debug: false,
        ),
        bufferSizeInSeconds: 5,
      );

  static bool _bindingsReady = false;

  final sherpa.VoiceActivityDetector _vad;

  /// Loads the sherpa-onnx native library once per isolate.
  static void ensureBindings() {
    if (!_bindingsReady) {
      sherpa.initBindings();
      _bindingsReady = true;
    }
  }

  @override
  double speechProbability(AudioFrame frame) {
    _vad.acceptWaveform(pcm16ToFloat(frame.samples));
    final speaking = _vad.isDetected();
    while (!_vad.isEmpty()) {
      _vad.pop();
    }
    return speaking ? 1 : 0;
  }

  @override
  void reset() => _vad.reset();

  /// Frees the native detector.
  void dispose() => _vad.free();
}

import 'dart:math' as math;

import 'audio_frame.dart';

/// Scores how likely a frame contains speech.
abstract interface class VoiceActivityDetector {
  /// Returns the speech probability of the frame, from 0 to 1.
  double speechProbability(AudioFrame frame);

  /// Clears any state kept between frames.
  void reset();
}

/// Energy-threshold detector used until Silero VAD arrives with the ASR library.
class EnergyVoiceActivityDetector implements VoiceActivityDetector {
  EnergyVoiceActivityDetector({this.thresholdDbfs = -45});

  final double thresholdDbfs;

  @override
  double speechProbability(AudioFrame frame) =>
      levelDbfs(frame) >= thresholdDbfs ? 1 : 0;

  @override
  void reset() {}

  /// Returns the RMS level of the frame in dBFS.
  static double levelDbfs(AudioFrame frame) {
    if (frame.samples.isEmpty) {
      return -120;
    }
    var sum = 0.0;
    for (final s in frame.samples) {
      sum += s * s;
    }
    final rms = math.sqrt(sum / frame.samples.length);
    if (rms == 0) {
      return -120;
    }
    return 20 * math.log(rms / 32768) / math.ln10;
  }
}

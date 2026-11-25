import 'dart:math' as math;

import 'audio_frame.dart';

/// Scores how likely a frame contains speech.
abstract interface class VoiceActivityDetector {
  /// Returns the speech probability of the frame, from 0 to 1.
  double speechProbability(AudioFrame frame);

  /// Clears any state kept between frames.
  void reset();
}

/// Energy detector used when Silero VAD cannot load; the threshold follows the room's noise floor up to a cap.
class EnergyVoiceActivityDetector implements VoiceActivityDetector {
  EnergyVoiceActivityDetector({
    this.thresholdDbfs = -45,
    this.marginDb = 10,
    this.maxFloorDbfs = -35,
    this.riseRate = 0.03,
  });

  static const _bucketFrames = 5;

  final double thresholdDbfs;
  final double marginDb;
  final double maxFloorDbfs;
  final double riseRate;

  late double _floor = thresholdDbfs - marginDb;
  double _bucketSum = 0;
  int _bucketCount = 0;

  /// The estimated background level: drops at once to quieter 100 ms stretches and rises slowly, capped at [maxFloorDbfs].
  double get noiseFloorDbfs => _floor;

  @override
  double speechProbability(AudioFrame frame) {
    final level = levelDbfs(frame);
    _track(level);
    return level >= math.max(thresholdDbfs, _floor + marginDb) ? 1 : 0;
  }

  @override
  void reset() {
    _floor = thresholdDbfs - marginDb;
    _bucketSum = 0;
    _bucketCount = 0;
  }

  /// Averages levels into 100 ms buckets and moves the floor towards each.
  void _track(double level) {
    _bucketSum += level;
    _bucketCount++;
    if (_bucketCount < _bucketFrames) {
      return;
    }
    final bucket = _bucketSum / _bucketCount;
    _bucketSum = 0;
    _bucketCount = 0;
    _floor = bucket < _floor
        ? bucket
        : math.min(maxFloorDbfs, _floor + (bucket - _floor) * riseRate);
  }

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

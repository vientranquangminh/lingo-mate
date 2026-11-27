import 'dart:math' as math;
import 'dart:typed_data';

/// Tells meeting speakers apart from voice embeddings: each new voice gets the next number, a known voice keeps its own.
class SpeakerTracker {
  SpeakerTracker({
    this.threshold = 0.4,
    this.minNewSpeakerMs = 1500,
    this.minLabelMs = 800,
    this.maxSpeakers = 6,
  });

  final double threshold;
  final int minNewSpeakerMs;
  final int minLabelMs;
  final int maxSpeakers;

  final _centroids = <Float32List>[];
  final _counts = <int>[];

  /// How many speakers have been heard so far.
  int get speakerCount => _centroids.length;

  /// Returns the number (from 1) of the speaker of [embedding], or null when the speech is too short to tell.
  int? assign(Float32List embedding, {required int durationMs}) {
    if (durationMs < minLabelMs || embedding.isEmpty) {
      return null;
    }
    final voice = _normalized(embedding);
    var best = -1;
    var bestScore = -1.0;
    for (var i = 0; i < _centroids.length; i++) {
      final score = _dot(_centroids[i], voice);
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    if (best >= 0 && bestScore >= threshold) {
      _learn(best, voice);
      return best + 1;
    }
    if (durationMs >= minNewSpeakerMs && _centroids.length < maxSpeakers) {
      _centroids.add(voice);
      _counts.add(1);
      return _centroids.length;
    }
    return best >= 0 ? best + 1 : null;
  }

  /// Forgets every speaker, for a new meeting.
  void reset() {
    _centroids.clear();
    _counts.clear();
  }

  /// Moves speaker [index]'s centroid towards [voice] as a running mean.
  void _learn(int index, Float32List voice) {
    final count = _counts[index] + 1;
    final centroid = _centroids[index];
    for (var i = 0; i < centroid.length; i++) {
      centroid[i] += (voice[i] - centroid[i]) / count;
    }
    _centroids[index] = _normalized(centroid);
    _counts[index] = math.min(count, 20);
  }

  /// Returns [v] scaled to unit length.
  static Float32List _normalized(Float32List v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final norm = math.sqrt(sum);
    return Float32List.fromList([for (final x in v) norm == 0 ? 0 : x / norm]);
  }

  /// Returns the dot product of two vectors of the same length.
  static double _dot(Float32List a, Float32List b) {
    var sum = 0.0;
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}

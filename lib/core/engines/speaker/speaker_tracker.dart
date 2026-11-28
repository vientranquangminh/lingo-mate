import 'dart:math' as math;
import 'dart:typed_data';

/// Tells meeting speakers apart from voice embeddings: after each sentence it re-clusters the whole meeting, so early guesses get corrected and numbers follow the order people first spoke.
class SpeakerTracker {
  SpeakerTracker({
    this.mergeThreshold = 0.35,
    this.minNewSpeakerMs = 1500,
    this.minLabelMs = 800,
    this.window = 150,
  });

  /// Builds a tracker from Remote Config `speaker_tuning` (`merge`, `minNewMs`, `minLabelMs`), keeping the defaults for missing keys.
  factory SpeakerTracker.fromJson(Map<String, dynamic> json) {
    final defaults = SpeakerTracker();
    return SpeakerTracker(
      mergeThreshold:
          (json['merge'] as num?)?.toDouble() ?? defaults.mergeThreshold,
      minNewSpeakerMs:
          (json['minNewMs'] as num?)?.toInt() ?? defaults.minNewSpeakerMs,
      minLabelMs: (json['minLabelMs'] as num?)?.toInt() ?? defaults.minLabelMs,
    );
  }

  final double mergeThreshold;
  final int minNewSpeakerMs;
  final int minLabelMs;
  final int window;

  final _voices = <Float32List>[];
  final _durations = <int>[];
  final _labels = <int?>[];

  /// The speaker number (from 1) of every sentence so far, in order; null where the speech was too short to tell.
  List<int?> get labels => List.unmodifiable(_labels);

  /// How many speakers have been heard so far.
  int get speakerCount => _labels.whereType<int>().toSet().length;

  /// Adds the voice of a sentence of [durationMs] and returns its speaker number, or null when too short; earlier labels may change too.
  int? assign(Float32List embedding, {required int durationMs}) {
    _voices.add(embedding.isEmpty ? embedding : _normalized(embedding));
    _durations.add(durationMs);
    _labels.add(null);
    _recluster();
    return _labels.last;
  }

  /// Forgets every speaker, for a new meeting.
  void reset() {
    _voices.clear();
    _durations.clear();
    _labels.clear();
  }

  /// Clusters the recent sentences by voice and numbers the clusters by first appearance, keeping older numbers.
  void _recluster() {
    final start = math.max(0, _voices.length - window);
    final usable = [
      for (var i = start; i < _voices.length; i++)
        if (_voices[i].isNotEmpty && _durations[i] >= minLabelMs) i,
    ];
    final anchors = usable
        .where((i) => _durations[i] >= minNewSpeakerMs)
        .toList();
    final seeds = anchors.isEmpty ? usable : anchors;
    if (seeds.isEmpty) {
      return;
    }
    final sums = [for (final i in seeds) _scaled(_voices[i], _weight(i))];
    final members = [
      for (final i in seeds) [i],
    ];
    final centroids = [for (final v in sums) _normalized(v)];
    final n = seeds.length;
    final alive = List.filled(n, true);
    final sim = [
      for (var a = 0; a < n; a++)
        Float64List.fromList([
          for (var b = 0; b < n; b++)
            a == b ? -2 : _dot(centroids[a], centroids[b]),
        ]),
    ];
    while (true) {
      var bestA = -1;
      var bestB = -1;
      var best = -2.0;
      for (var a = 0; a < n; a++) {
        if (!alive[a]) {
          continue;
        }
        final row = sim[a];
        for (var b = a + 1; b < n; b++) {
          if (alive[b] && row[b] > best) {
            best = row[b];
            bestA = a;
            bestB = b;
          }
        }
      }
      if (bestA < 0 || best < mergeThreshold) {
        break;
      }
      final merged = sums[bestA];
      final other = sums[bestB];
      for (var k = 0; k < merged.length; k++) {
        merged[k] += other[k];
      }
      members[bestA].addAll(members[bestB]);
      members[bestB] = const [];
      alive[bestB] = false;
      centroids[bestA] = _normalized(merged);
      for (var c = 0; c < n; c++) {
        if (alive[c] && c != bestA) {
          final score = _dot(centroids[bestA], centroids[c]);
          sim[bestA][c] = score;
          sim[c][bestA] = score;
        }
      }
    }
    final kept = [
      for (var c = 0; c < n; c++)
        if (alive[c]) c,
    ];
    final keptMembers = [for (final c in kept) members[c]];
    final keptCentroids = [for (final c in kept) centroids[c]];
    final clusterOf = <int, int>{};
    for (var c = 0; c < keptMembers.length; c++) {
      for (final i in keptMembers[c]) {
        clusterOf[i] = c;
      }
    }
    for (final i in usable) {
      if (clusterOf.containsKey(i)) {
        continue;
      }
      var best = 0;
      var bestScore = -2.0;
      for (var c = 0; c < keptCentroids.length; c++) {
        final score = _dot(keptCentroids[c], _voices[i]);
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      clusterOf[i] = best;
    }
    final firstSeen = <int, int>{};
    for (final i in usable) {
      firstSeen.putIfAbsent(clusterOf[i]!, () => i);
    }
    final previous = <int, int>{};
    for (final c in firstSeen.keys) {
      final votes = <int, int>{};
      for (final i in usable) {
        final old = _labels[i];
        if (clusterOf[i] == c && old != null) {
          votes[old] = (votes[old] ?? 0) + _durations[i];
        }
      }
      if (votes.isNotEmpty) {
        previous[c] =
            (votes.entries.toList()..sort((x, y) => y.value - x.value))
                .first
                .key;
      }
    }
    final used = <int>{};
    final number = <int, int>{};
    final ordered = firstSeen.keys.toList()
      ..sort((x, y) => firstSeen[x]! - firstSeen[y]!);
    for (final c in ordered) {
      final old = previous[c];
      if (old != null && !used.contains(old)) {
        number[c] = old;
        used.add(old);
      }
    }
    var next = 1;
    for (final c in ordered) {
      if (number.containsKey(c)) {
        continue;
      }
      while (used.contains(next)) {
        next++;
      }
      number[c] = next;
      used.add(next);
    }
    for (final i in usable) {
      _labels[i] = number[clusterOf[i]];
    }
  }

  /// How much sentence [i] counts in its cluster: its length in seconds, capped.
  double _weight(int i) => math.min(_durations[i], 8000) / 1000;

  /// Returns [v] multiplied by [w].
  static Float32List _scaled(Float32List v, double w) =>
      Float32List.fromList([for (final x in v) x * w]);

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

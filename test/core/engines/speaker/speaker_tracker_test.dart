import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/speaker/speaker_tracker.dart';

/// A voice along axis [axis], tilted by [noise] towards the next axis.
Float32List voice(int axis, {double noise = 0}) {
  final v = Float32List(8);
  v[axis] = 1;
  v[(axis + 1) % 8] = noise;
  return v;
}

/// A voice halfway (by [mix]) between axes [a] and [b].
Float32List blend(int a, int b, double mix) {
  final v = Float32List(8);
  v[a] = math.cos(mix * math.pi / 2);
  v[b] = math.sin(mix * math.pi / 2);
  return v;
}

void main() {
  test('numbers voices in the order they first speak and keeps them', () {
    final tracker = SpeakerTracker();

    expect(tracker.assign(voice(0), durationMs: 2000), 1);
    expect(tracker.assign(voice(3), durationMs: 2000), 2);
    expect(tracker.assign(voice(0, noise: 0.3), durationMs: 1200), 1);
    expect(tracker.assign(voice(3, noise: 0.2), durationMs: 2000), 2);
    expect(tracker.labels, [1, 2, 1, 2]);
    expect(tracker.speakerCount, 2);
  });

  test('leaves very short speech unlabelled', () {
    final tracker = SpeakerTracker();

    expect(tracker.assign(voice(0), durationMs: 500), isNull);
    expect(tracker.speakerCount, 0);
  });

  test(
    'a short sentence joins the closest speaker instead of starting one',
    () {
      final tracker = SpeakerTracker()..assign(voice(0), durationMs: 2000);

      expect(tracker.assign(voice(5), durationMs: 1000), 1);
      expect(tracker.speakerCount, 1);
    },
  );

  test(
    're-clustering corrects an early split once more of the voice is heard',
    () {
      final tracker = SpeakerTracker(mergeThreshold: 0.6)
        ..assign(blend(0, 1, 0), durationMs: 2000)
        ..assign(blend(0, 1, 0.6), durationMs: 2000);
      expect(tracker.labels, [1, 2]);

      tracker.assign(blend(0, 1, 0.3), durationMs: 4000);

      expect(tracker.labels, [1, 1, 1]);
      expect(tracker.speakerCount, 1);
    },
  );

  test(
    'reads its thresholds from Remote Config and reset forgets everyone',
    () {
      final tracker = SpeakerTracker.fromJson(const {
        'merge': 0.5,
        'minNewMs': 2000,
        'minLabelMs': 600,
      });

      expect(tracker.mergeThreshold, 0.5);
      expect(tracker.minNewSpeakerMs, 2000);
      expect(tracker.minLabelMs, 600);
      expect(SpeakerTracker.fromJson(const {}).mergeThreshold, 0.35);

      tracker
        ..assign(voice(0), durationMs: 2500)
        ..reset();
      expect(tracker.labels, isEmpty);
    },
  );

  test(
    'keeps the same numbers in a long meeting beyond the clustering window',
    () {
      final tracker = SpeakerTracker(window: 10);
      for (var n = 0; n < 40; n++) {
        tracker.assign(voice(n.isEven ? 0 : 4, noise: 0.1), durationMs: 2000);
      }

      expect(tracker.speakerCount, 2);
      expect(tracker.labels.sublist(30), [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]);
    },
  );
}

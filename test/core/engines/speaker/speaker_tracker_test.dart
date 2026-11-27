import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/speaker/speaker_tracker.dart';

/// A voice pointing mostly along axis [axis], nudged by [noise] on the next axis.
Float32List voice(int axis, {double noise = 0}) {
  final v = Float32List(8);
  v[axis] = 1;
  v[(axis + 1) % 8] = noise;
  return v;
}

void main() {
  test('numbers voices in the order they first speak and keeps them', () {
    final tracker = SpeakerTracker();

    expect(tracker.assign(voice(0), durationMs: 2000), 1);
    expect(tracker.assign(voice(3), durationMs: 2000), 2);
    expect(tracker.assign(voice(0, noise: 0.3), durationMs: 1200), 1);
    expect(tracker.assign(voice(3, noise: 0.2), durationMs: 2000), 2);
    expect(tracker.speakerCount, 2);
  });

  test('leaves very short speech unlabelled', () {
    final tracker = SpeakerTracker();

    expect(tracker.assign(voice(0), durationMs: 500), isNull);
    expect(tracker.speakerCount, 0);
  });

  test(
    'a short unknown voice is given the closest speaker instead of a new one',
    () {
      final tracker = SpeakerTracker()..assign(voice(0), durationMs: 2000);

      expect(tracker.assign(voice(5), durationMs: 1000), 1);
      expect(tracker.speakerCount, 1);
    },
  );

  test('stops adding speakers at the limit, and reset forgets them', () {
    final tracker = SpeakerTracker(maxSpeakers: 2)
      ..assign(voice(0), durationMs: 2000)
      ..assign(voice(2), durationMs: 2000);

    expect(tracker.assign(voice(4), durationMs: 2000), isIn([1, 2]));
    expect(tracker.speakerCount, 2);

    tracker.reset();
    expect(tracker.speakerCount, 0);
    expect(tracker.assign(voice(4), durationMs: 2000), 1);
  });
}

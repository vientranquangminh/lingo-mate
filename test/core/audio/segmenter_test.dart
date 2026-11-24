import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/audio/segmenter.dart';

import 'audio_test_utils.dart';

void main() {
  late Segmenter segmenter;
  late List<AudioSegment> out;
  late int clock;

  setUp(() {
    segmenter = Segmenter();
    out = [];
    clock = 0;
  });

  /// Runs a speech pattern through the segmenter, continuing the stream time.
  void run(List<(int, bool)> pattern) => clock = feedPattern(
    pattern,
    (f, p) => out.addAll(segmenter.add(f, p)),
    startMs: clock,
  );

  test('emits a segment after 600 ms of silence, with 200 ms pre-roll', () {
    run([(300, false), (1000, true), (580, false)]);
    expect(out, isEmpty);

    run([(20, false)]);

    expect(out, hasLength(1));
    expect(out.single.startMs, 100);
    expect(out.single.endMs, 1300);
    expect(out.single.samples.length, 1200 * AudioFormat.samplesPerMs);
  });

  test('keeps pauses shorter than 600 ms inside one segment', () {
    run([(500, true), (400, false), (500, true), (600, false)]);

    expect(out, hasLength(1));
    expect(out.single.startMs, 0);
    expect(out.single.endMs, 1400);
  });

  test('drops speech shorter than 400 ms', () {
    run([(300, true), (600, false)]);

    expect(out, isEmpty);
  });

  test('cuts a long monologue at the latest pause of at least 250 ms', () {
    run([(6000, true), (300, false), (4000, true), (260, false)]);
    run([(5000, true)]);

    expect(out, hasLength(1));
    expect(out.single.startMs, 0);
    expect(out.single.endMs, 10300);

    run([(600, false)]);

    expect(out, hasLength(2));
    expect(out[1].startMs, 10420);
    expect(out[1].endMs, 15560);
  });

  test('hard-cuts at 15 s when no pause is long enough', () {
    run([(7000, true), (200, false), (9000, true)]);

    expect(out, hasLength(1));
    expect(out.single.durationMs, 15000);
  });

  test('flush emits the segment in progress', () {
    run([(800, true)]);

    final flushed = segmenter.flush();

    expect(flushed, hasLength(1));
    expect(flushed.single.durationMs, 800);
  });

  test('reports the share of speech frames', () {
    run([(500, true), (500, false), (500, true), (600, false)]);

    expect(out.single.speechRatio, closeTo(1000 / 1500, 0.001));
  });
}

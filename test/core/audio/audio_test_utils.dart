import 'dart:typed_data';

import 'package:lingo_mate/core/audio/audio_frame.dart';

/// Returns a 20 ms frame at [startMs] filled with a constant [amplitude].
AudioFrame frameAt(int startMs, {int amplitude = 0}) => AudioFrame(
  samples: Int16List(AudioFormat.samplesPerFrame)
    ..fillRange(0, AudioFormat.samplesPerFrame, amplitude),
  startMs: startMs,
);

/// Returns PCM16 bytes for [ms] milliseconds at a constant [amplitude].
Uint8List pcm(int ms, {int amplitude = 0}) {
  final samples = Int16List(ms * AudioFormat.samplesPerMs)
    ..fillRange(0, ms * AudioFormat.samplesPerMs, amplitude);
  return samples.buffer.asUint8List();
}

/// Feeds a speech pattern as 20 ms frames from [startMs]: each entry is (durationMs, isSpeech); returns the next start time.
int feedPattern(
  List<(int, bool)> pattern,
  void Function(AudioFrame frame, double probability) onFrame, {
  int startMs = 0,
}) {
  var t = startMs;
  for (final (ms, speech) in pattern) {
    for (var i = 0; i < ms ~/ AudioFormat.frameMs; i++) {
      onFrame(frameAt(t), speech ? 1 : 0);
      t += AudioFormat.frameMs;
    }
  }
  return t;
}

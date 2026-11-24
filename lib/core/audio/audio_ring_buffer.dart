import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_frame.dart';

/// Keeps the most recent audio in memory only, for replays and ASR retries.
class AudioRingBuffer {
  AudioRingBuffer({int capacityMs = 30000})
    : _buffer = Int16List(capacityMs * AudioFormat.samplesPerMs);

  final Int16List _buffer;
  int _written = 0;

  int get capacityMs => _buffer.length ~/ AudioFormat.samplesPerMs;

  /// Stream time in ms of the oldest sample still held.
  int get oldestMs =>
      math.max(0, _written - _buffer.length) ~/ AudioFormat.samplesPerMs;

  /// Stream time in ms just after the newest sample.
  int get newestMs => _written ~/ AudioFormat.samplesPerMs;

  /// Appends a frame, overwriting the oldest audio when full.
  void add(AudioFrame frame) {
    final start = frame.startMs * AudioFormat.samplesPerMs;
    if (start > _written) {
      _written = start;
    }
    for (final s in frame.samples) {
      _buffer[_written % _buffer.length] = s;
      _written++;
    }
  }

  /// Returns the audio between two stream times, or null when it is no longer held.
  Int16List? read(int startMs, int endMs) {
    if (startMs < oldestMs || endMs > newestMs || endMs <= startMs) {
      return null;
    }
    final from = startMs * AudioFormat.samplesPerMs;
    final to = endMs * AudioFormat.samplesPerMs;
    final out = Int16List(to - from);
    for (var i = from; i < to; i++) {
      out[i - from] = _buffer[i % _buffer.length];
    }
    return out;
  }

  /// Erases all held audio.
  void clear() {
    _buffer.fillRange(0, _buffer.length, 0);
    _written = 0;
  }
}

import 'dart:typed_data';

import 'audio_frame.dart';

/// Turns PCM16 byte chunks of any size into timestamped 20 ms frames.
class FrameChunker {
  final _pending = BytesBuilder(copy: false);
  int _samplesEmitted = 0;

  static const _bytesPerFrame = AudioFormat.samplesPerFrame * 2;

  /// Adds a chunk of little-endian PCM16 bytes and returns the complete frames.
  List<AudioFrame> add(Uint8List bytes) {
    _pending.add(bytes);
    if (_pending.length < _bytesPerFrame) {
      return const [];
    }
    final all = _pending.takeBytes();
    final frameCount = all.length ~/ _bytesPerFrame;
    final frames = <AudioFrame>[];
    final data = ByteData.sublistView(all);
    for (var f = 0; f < frameCount; f++) {
      final samples = Int16List(AudioFormat.samplesPerFrame);
      final base = f * _bytesPerFrame;
      for (var i = 0; i < samples.length; i++) {
        samples[i] = data.getInt16(base + i * 2, Endian.little);
      }
      frames.add(
        AudioFrame(
          samples: samples,
          startMs: _samplesEmitted ~/ AudioFormat.samplesPerMs,
        ),
      );
      _samplesEmitted += AudioFormat.samplesPerFrame;
    }
    final rest = all.length - frameCount * _bytesPerFrame;
    if (rest > 0) {
      _pending.add(Uint8List.sublistView(all, all.length - rest));
    }
    return frames;
  }

  /// Drops buffered bytes and restarts timestamps at zero.
  void reset() {
    _pending.clear();
    _samplesEmitted = 0;
  }
}

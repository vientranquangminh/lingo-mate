import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Audio format used across the pipeline: 16 kHz mono PCM16 in 20 ms frames.
abstract final class AudioFormat {
  static const sampleRate = 16000;
  static const frameMs = 20;
  static const samplesPerFrame = sampleRate * frameMs ~/ 1000;
  static const samplesPerMs = sampleRate ~/ 1000;
}

/// One 20 ms block of mono PCM16 samples with its start time in the stream.
class AudioFrame extends Equatable {
  const AudioFrame({required this.samples, required this.startMs});

  final Int16List samples;
  final int startMs;

  int get endMs => startMs + samples.length ~/ AudioFormat.samplesPerMs;

  @override
  List<Object?> get props => [startMs, samples.length];
}

/// A speech segment cut by the segmenter, ready for speech recognition.
class AudioSegment extends Equatable {
  const AudioSegment({
    required this.samples,
    required this.startMs,
    required this.endMs,
    required this.speechRatio,
  });

  final Int16List samples;
  final int startMs;
  final int endMs;
  final double speechRatio;

  int get durationMs => endMs - startMs;

  /// Returns the samples as little-endian PCM16 bytes.
  Uint8List toPcmBytes() =>
      samples.buffer.asUint8List(samples.offsetInBytes, samples.lengthInBytes);

  @override
  List<Object?> get props => [startMs, endMs, samples.length];
}

import 'dart:async';
import 'dart:typed_data';

import 'audio_capture.dart';
import 'audio_frame.dart';
import 'audio_ring_buffer.dart';
import 'echo_gate.dart';
import 'frame_chunker.dart';
import 'segmenter.dart';
import 'voice_activity_detector.dart';

/// Microphone → frames → ring buffer → echo gate → VAD → segments, plus raw chunks for Live.
class AudioPipeline {
  AudioPipeline({
    required this._capture,
    required this._vad,
    required this.echoGate,
    Segmenter? segmenter,
    AudioRingBuffer? ringBuffer,
  }) : _segmenter = segmenter ?? Segmenter(),
       ringBuffer = ringBuffer ?? AudioRingBuffer();

  static const liveChunkMs = 100;
  static const partialEveryMs = 1000;

  final AudioCapture _capture;
  final VoiceActivityDetector _vad;
  final Segmenter _segmenter;
  final EchoGate echoGate;
  final AudioRingBuffer ringBuffer;
  final _chunker = FrameChunker();

  final _segments = StreamController<AudioSegment>.broadcast();
  final _liveChunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();
  final _partials = StreamController<AudioSegment>.broadcast();
  int _sincePartialMs = 0;
  final _liveBuffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  bool _gateWasOpen = true;

  /// Speech segments for the Offline and Standard pipelines.
  Stream<AudioSegment> get segments => _segments.stream;

  /// The utterance in progress so far, about once a second while someone speaks.
  Stream<AudioSegment> get partials => _partials.stream;

  /// 100 ms PCM16 chunks for the Live engine, gated like segments.
  Stream<Uint8List> get liveChunks => _liveChunks.stream;

  /// Input level in dBFS per frame, for the mic meter.
  Stream<double> get levels => _levels.stream;

  bool get isRunning => _subscription != null;

  /// Opens the microphone and starts producing segments; returns false without permission.
  Future<bool> start([
    AudioCaptureConfig config = const AudioCaptureConfig(),
  ]) async {
    if (isRunning) {
      return true;
    }
    if (!await _capture.ensurePermission()) {
      return false;
    }
    _chunker.reset();
    _segmenter.reset();
    _vad.reset();
    ringBuffer.clear();
    final stream = await _capture.start(config);
    _subscription = stream.listen(addPcm);
    return true;
  }

  /// Stops the microphone, emits the segment in progress and clears held audio.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _capture.stop();
    _segmenter.flush().forEach(_segments.add);
    _liveBuffer.clear();
    ringBuffer.clear();
  }

  /// Feeds PCM16 bytes through the pipeline; used by the capture stream and the benchmark runner.
  void addPcm(Uint8List bytes) {
    for (final frame in _chunker.add(bytes)) {
      _addFrame(frame);
    }
  }

  /// Releases the streams.
  Future<void> dispose() async {
    await stop();
    await _segments.close();
    await _liveChunks.close();
    await _levels.close();
    await _partials.close();
  }

  /// Routes one frame through the ring buffer, gate, VAD and segmenter.
  void _addFrame(AudioFrame frame) {
    ringBuffer.add(frame);
    _levels.add(EnergyVoiceActivityDetector.levelDbfs(frame));
    final open = echoGate.isOpen;
    if (!open) {
      if (_gateWasOpen) {
        _segmenter.reset();
        _vad.reset();
        _liveBuffer.clear();
        _sincePartialMs = 0;
      }
      _gateWasOpen = false;
      return;
    }
    _gateWasOpen = true;
    _addLive(frame);
    final probability = _vad.speechProbability(frame);
    final finished = _segmenter.add(frame, probability)..forEach(_segments.add);
    _addPartial(frame, finished.isNotEmpty);
  }

  /// Emits a snapshot of the utterance in progress every [partialEveryMs].
  void _addPartial(AudioFrame frame, bool finished) {
    if (finished || !_segmenter.isActive) {
      _sincePartialMs = 0;
      return;
    }
    _sincePartialMs += frame.samples.length ~/ AudioFormat.samplesPerMs;
    if (_sincePartialMs < partialEveryMs || !_partials.hasListener) {
      return;
    }
    _sincePartialMs = 0;
    final snapshot = _segmenter.snapshot();
    if (snapshot != null) {
      _partials.add(snapshot);
    }
  }

  /// Collects frames into 100 ms chunks for the Live engine.
  void _addLive(AudioFrame frame) {
    if (!_liveChunks.hasListener) {
      return;
    }
    final samples = frame.samples;
    _liveBuffer.add(
      samples.buffer.asUint8List(samples.offsetInBytes, samples.lengthInBytes),
    );
    if (_liveBuffer.length >= liveChunkMs * AudioFormat.samplesPerMs * 2) {
      _liveChunks.add(_liveBuffer.takeBytes());
    }
  }
}

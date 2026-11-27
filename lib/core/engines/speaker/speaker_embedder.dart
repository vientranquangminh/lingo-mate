import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../audio/audio_frame.dart';
import '../asr/asr_models.dart';

/// Turns a speech segment into a voice embedding that is close for the same speaker.
abstract interface class SpeakerEmbedder {
  /// Returns the voice embedding of [segment], or null when it cannot be computed.
  Future<Float32List?> embed(AudioSegment segment);
}

/// [SpeakerEmbedder] on a sherpa-onnx speaker model (3D-Speaker CAM++), computed on a worker isolate.
class SherpaSpeakerEmbedder implements SpeakerEmbedder {
  SherpaSpeakerEmbedder(this.modelPath, {this.threads = 1});

  final String modelPath;
  final int threads;

  SendPort? _toWorker;
  Future<void>? _starting;
  final _pending = <int, Completer<Float32List?>>{};
  int _nextId = 0;

  @override
  Future<Float32List?> embed(AudioSegment segment) async {
    await (_starting ??= _start());
    final id = _nextId++;
    final completer = Completer<Float32List?>();
    _pending[id] = completer;
    _toWorker!.send([id, pcm16ToFloat(segment.samples)]);
    return completer.future;
  }

  /// Spawns the worker and waits until the model is loaded.
  Future<void> _start() async {
    final fromWorker = ReceivePort();
    final ready = Completer<SendPort>();
    fromWorker.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final [id as int, value as Float32List?] = message as List<Object?>;
      _pending.remove(id)?.complete(value);
    });
    await Isolate.spawn(_worker, [fromWorker.sendPort, modelPath, threads]);
    _toWorker = await ready.future;
  }

  /// Worker isolate: loads the speaker model once and embeds segments in order.
  static void _worker(List<Object?> args) {
    final [reply as SendPort, model as String, threads as int] = args;
    sherpa.initBindings();
    final extractor = sherpa.SpeakerEmbeddingExtractor(
      config: sherpa.SpeakerEmbeddingExtractorConfig(
        model: model,
        numThreads: threads,
      ),
    );
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((message) {
      final [id as int, samples as Float32List] = message as List<Object?>;
      try {
        final stream = extractor.createStream()
          ..acceptWaveform(samples: samples, sampleRate: AudioFormat.sampleRate)
          ..inputFinished();
        final embedding = extractor.isReady(stream)
            ? extractor.compute(stream)
            : null;
        stream.free();
        reply.send([id, embedding]);
      } catch (_) {
        reply.send([id, null]);
      }
    });
  }
}

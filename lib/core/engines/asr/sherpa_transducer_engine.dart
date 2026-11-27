import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../audio/audio_frame.dart';
import '../engines.dart';
import 'asr_models.dart';

/// A zipformer transducer for one language through sherpa-onnx, decoded on a worker isolate; trained on regional accents, so it hears them better than Whisper.
class SherpaTransducerEngine implements SpeechRecognizerEngine {
  SherpaTransducerEngine(this.model, {this.threads = 2});

  final TransducerModel model;
  final int threads;

  Isolate? _isolate;
  SendPort? _toWorker;
  final _pending = <int, Completer<String>>{};
  int _nextId = 0;
  Future<void>? _starting;

  @override
  bool get supportsPartials => true;

  @override
  String get id => 'sherpa-transducer-${model.name}';

  @override
  Future<void> ensureReady(String lang) => _starting ??= _start();

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    await ensureReady(model.lang);
    final id = _nextId++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _toWorker!.send([id, pcm16ToFloat(segment.samples)]);
    return AsrResult(
      text: sentenceCase(await completer.future),
      lang: model.lang,
    );
  }

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async => null;

  /// Turns the model's upper-case output into a sentence: lower case with a capital first letter.
  static String sentenceCase(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) {
      return lower;
    }
    return lower[0].toUpperCase() + lower.substring(1);
  }

  /// Stops the worker isolate and frees the model.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorker = null;
    _starting = null;
    for (final c in _pending.values) {
      c.completeError(StateError('engine disposed'));
    }
    _pending.clear();
  }

  /// Spawns the worker and waits until it is ready to decode.
  Future<void> _start() async {
    final fromWorker = ReceivePort();
    final ready = Completer<SendPort>();
    fromWorker.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final [id as int, ok as bool, value as String] = message as List<Object?>;
      final completer = _pending.remove(id);
      if (ok) {
        completer?.complete(value);
      } else {
        completer?.completeError(StateError(value));
      }
    });
    _isolate = await Isolate.spawn(_worker, [
      fromWorker.sendPort,
      model.encoder,
      model.decoder,
      model.joiner,
      model.tokens,
      threads,
    ]);
    _toWorker = await ready.future;
  }

  /// Worker isolate: loads the transducer once and decodes segments in order.
  static void _worker(List<Object?> args) {
    final [
      reply as SendPort,
      encoder as String,
      decoder as String,
      joiner as String,
      tokens as String,
      threads as int,
    ] = args;
    sherpa.initBindings();
    final recognizer = sherpa.OfflineRecognizer(
      sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          transducer: sherpa.OfflineTransducerModelConfig(
            encoder: encoder,
            decoder: decoder,
            joiner: joiner,
          ),
          tokens: tokens,
          numThreads: threads,
          debug: false,
        ),
      ),
    );
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((message) {
      final [id as int, samples as Float32List] = message as List<Object?>;
      try {
        final stream = recognizer.createStream()
          ..acceptWaveform(
            samples: samples,
            sampleRate: AudioFormat.sampleRate,
          );
        recognizer.decode(stream);
        final text = recognizer.getResult(stream).text;
        stream.free();
        reply.send([id, true, text]);
      } catch (e) {
        reply.send([id, false, '$e']);
      }
    });
  }
}

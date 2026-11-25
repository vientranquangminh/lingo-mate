import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../../audio/audio_frame.dart';
import '../engines.dart';
import 'asr_models.dart';

/// Whisper through sherpa-onnx, decoded on a worker isolate so the UI stays responsive.
class SherpaWhisperEngine implements SpeechRecognizerEngine {
  SherpaWhisperEngine(this.model, {this.threads = 2});

  final SherpaWhisperModel model;
  final int threads;

  Isolate? _isolate;
  SendPort? _toWorker;
  final _pending = <int, Completer<(String, String)>>{};
  int _nextId = 0;
  Future<void>? _starting;

  @override
  bool get supportsPartials => true;

  @override
  String get id => 'sherpa-whisper-${model.name}';

  @override
  Future<void> ensureReady(String lang) => _starting ??= _start();

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    await ensureReady(hintLang ?? '');
    final (text, detected) = await _decode(segment, hintLang ?? '');
    return AsrResult(text: text, lang: hintLang ?? detected);
  }

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async {
    await ensureReady('');
    final (_, detected) = await _decode(segment, '');
    return candidates.contains(detected) ? detected : null;
  }

  /// Sends [segment] to the worker; an empty [lang] lets Whisper detect it. Returns the text and the detected language.
  Future<(String, String)> _decode(AudioSegment segment, String lang) {
    final id = _nextId++;
    final completer = Completer<(String, String)>();
    _pending[id] = completer;
    _toWorker!.send([id, lang, pcm16ToFloat(segment.samples)]);
    return completer.future;
  }

  /// Stops the worker isolate and frees the models.
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
      final [id as int, ok as bool, value as String, lang as String] =
          message as List<Object?>;
      final completer = _pending.remove(id);
      if (ok) {
        completer?.complete((value, lang));
      } else {
        completer?.completeError(StateError(value));
      }
    });
    _isolate = await Isolate.spawn(_worker, [
      fromWorker.sendPort,
      model.encoder,
      model.decoder,
      model.tokens,
      threads,
    ]);
    _toWorker = await ready.future;
  }

  /// Reduces Whisper's language tag (`<|vi|>`, `vi`) to the BCP-47 base code.
  static String _shortLang(String tag) =>
      tag.replaceAll(RegExp('[<|>]'), '').trim().toLowerCase();

  /// Worker isolate: keeps one recognizer per language and decodes segments in order.
  static void _worker(List<Object?> args) {
    final [
      reply as SendPort,
      encoder as String,
      decoder as String,
      tokens as String,
      threads as int,
    ] = args;
    sherpa.initBindings();
    final recognizers = <String, sherpa.OfflineRecognizer>{};
    final inbox = ReceivePort();
    reply.send(inbox.sendPort);
    inbox.listen((message) {
      final [id as int, lang as String, samples as Float32List] =
          message as List<Object?>;
      try {
        final recognizer = recognizers.putIfAbsent(
          lang,
          () => sherpa.OfflineRecognizer(
            sherpa.OfflineRecognizerConfig(
              model: sherpa.OfflineModelConfig(
                whisper: sherpa.OfflineWhisperModelConfig(
                  encoder: encoder,
                  decoder: decoder,
                  language: lang,
                  task: 'transcribe',
                ),
                tokens: tokens,
                numThreads: threads,
                debug: false,
              ),
            ),
          ),
        );
        final stream = recognizer.createStream()
          ..acceptWaveform(
            samples: samples,
            sampleRate: AudioFormat.sampleRate,
          );
        recognizer.decode(stream);
        final result = recognizer.getResult(stream);
        stream.free();
        reply.send([id, true, result.text.trim(), _shortLang(result.lang)]);
      } catch (e) {
        reply.send([id, false, '$e', '']);
      }
    });
  }
}

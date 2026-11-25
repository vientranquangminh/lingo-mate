import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import '../../audio/audio_frame.dart';
import '../engines.dart';
import 'asr_models.dart';

/// Whisper through whisper.cpp; inference runs on native threads.
class WhisperCppEngine implements SpeechRecognizerEngine {
  WhisperCppEngine(this.model, {this.threads = 4});

  final WhisperCppModel model;
  final int threads;

  Future<WhisperEngine>? _engine;

  @override
  bool get supportsPartials => true;

  @override
  String get id => 'whisper-cpp-${model.name}';

  @override
  Future<void> ensureReady(String lang) async {
    await (_engine ??= WhisperEngine.load(model.path));
  }

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    final engine = await (_engine ??= WhisperEngine.load(model.path));
    final result = await engine
        .transcribe(
          pcm16ToFloat(segment.samples),
          options: TranscribeOptions(
            threads: threads,
            language: hintLang ?? 'auto',
            noTimestamps: true,
            singleSegment: true,
            tokenTimestamps: false,
            greedyBestOf: 1,
            audioContext: audioContextFor(segment.samples.length),
          ),
        )
        .result;
    return AsrResult(
      text: result.text.trim(),
      lang: hintLang ?? result.language,
    );
  }

  /// Returns the encoder context for [samples] of 16 kHz audio, so short speech skips the padded 30 s window.
  static int audioContextFor(int samples) {
    const fullContext = 1500;
    const fullSamples = 30 * AudioFormat.sampleRate;
    const margin = 64;
    const minContext = 256;
    final needed = (samples * fullContext / fullSamples).ceil() + margin;
    return needed.clamp(minContext, fullContext);
  }

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async {
    final lang = (await transcribe(segment)).lang;
    return candidates.contains(lang) ? lang : null;
  }

  /// Frees the loaded model.
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    (await engine)?.dispose();
  }
}

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
          ),
        )
        .result;
    return AsrResult(
      text: result.text.trim(),
      lang: hintLang ?? result.language,
    );
  }

  /// Frees the loaded model.
  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    (await engine)?.dispose();
  }
}

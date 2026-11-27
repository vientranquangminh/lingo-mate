import '../../audio/audio_frame.dart';
import '../engines.dart';

/// Sends each language to its own recognizer when one is installed (e.g. a Vietnamese transducer), and every other language to [fallback].
class LanguageRoutedRecognizer implements SpeechRecognizerEngine {
  LanguageRoutedRecognizer({required this.byLanguage, this.fallback});

  final Map<String, SpeechRecognizerEngine> byLanguage;
  final SpeechRecognizerEngine? fallback;

  @override
  String get id => [
    ...byLanguage.entries.map((e) => '${e.key}:${e.value.id}'),
    ?fallback?.id,
  ].join('+');

  @override
  bool get supportsPartials =>
      byLanguage.values.every((e) => e.supportsPartials) &&
      (fallback?.supportsPartials ?? true);

  /// Returns the recognizer for [lang], or null when none can hear it.
  SpeechRecognizerEngine? engineFor(String? lang) =>
      byLanguage[lang] ?? fallback;

  @override
  Future<void> ensureReady(String lang) async =>
      engineFor(lang)?.ensureReady(lang);

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    final engine = engineFor(hintLang);
    if (engine == null) {
      return AsrResult(text: '', lang: hintLang ?? '');
    }
    return engine.transcribe(segment, hintLang: hintLang);
  }

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async =>
      fallback?.detectLanguage(segment, candidates: candidates) ??
      (candidates.length == 1 && byLanguage.containsKey(candidates.single)
          ? candidates.single
          : null);
}

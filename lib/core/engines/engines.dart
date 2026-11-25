import 'package:equatable/equatable.dart';

import '../audio/audio_frame.dart';

/// The three translation engines (D-04).
enum EngineKind { offline, standard, live }

/// Text recognised from one speech segment.
class AsrResult extends Equatable {
  const AsrResult({required this.text, required this.lang});

  final String text;
  final String lang;

  @override
  List<Object?> get props => [text, lang];
}

/// On-device speech recognition of speech segments.
abstract interface class SpeechRecognizerEngine {
  /// Short id shown in devtools and benchmark CSVs.
  String get id;

  /// Loads the model for a language, downloading nothing.
  Future<void> ensureReady(String lang);

  /// Recognises one segment, using [hintLang] when the language is known.
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang});

  /// Returns the language spoken in [segment] when it is one of [candidates], else null.
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  });
}

/// A text translation request with recent context.
class TranslateRequest extends Equatable {
  const TranslateRequest({
    required this.from,
    required this.to,
    required this.text,
    this.context = const [],
    this.glossary = const {},
  });

  final String from;
  final String to;
  final String text;
  final List<String> context;
  final Map<String, String> glossary;

  /// Returns a copy with [terms] as the glossary.
  TranslateRequest withGlossary(Map<String, String> terms) => TranslateRequest(
    from: from,
    to: to,
    text: text,
    context: context,
    glossary: terms,
  );

  @override
  List<Object?> get props => [from, to, text, context, glossary];
}

/// Translated text and the engine that produced it.
class Translation extends Equatable {
  const Translation({required this.text, required this.engine});

  final String text;
  final EngineKind engine;

  @override
  List<Object?> get props => [text, engine];
}

/// Text translation (ML Kit offline, Gemini online).
abstract interface class TextTranslatorEngine {
  /// Short id shown in devtools and benchmark CSVs.
  String get id;

  EngineKind get kind;

  /// Whether this engine can translate the pair right now.
  Future<bool> isAvailable(String from, String to);

  /// Translates one utterance.
  Future<Translation> translate(TranslateRequest request);
}

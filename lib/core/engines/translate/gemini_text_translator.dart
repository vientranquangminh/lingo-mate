import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/generative_model_factory.dart';
import '../engines.dart';
import 'translator_prompt.dart';

/// Sends a system instruction and a user message to Gemini and returns its text.
typedef GeminiGenerate = Future<String?> Function({
  required String system,
  required String user,
});

/// Standard engine translator: Gemini Flash-Lite through Firebase AI Logic (doc 03 §6.2).
class GeminiTextTranslator implements TextTranslatorEngine {
  GeminiTextTranslator(
    this._generate, {
    this.timeout = const Duration(seconds: 6),
  });

  /// Builds the translator on Firebase AI Logic with the Remote Config model.
  factory GeminiTextTranslator.firebase(GenerativeModelFactory factory) =>
      GeminiTextTranslator(({required system, required user}) async {
        final response = await factory
            .translationModel(systemInstruction: system)
            .generateContent([Content.text(user)]);
        return response.text;
      });

  final GeminiGenerate _generate;
  final Duration timeout;

  @override
  String get id => 'gemini';

  @override
  EngineKind get kind => EngineKind.standard;

  @override
  Future<bool> isAvailable(String from, String to) async => from != to;

  @override
  Future<Translation> translate(TranslateRequest request) async {
    final system = TranslatorPrompt.system(from: request.from, to: request.to);
    final user = TranslatorPrompt.user(
      text: request.text,
      context: request.context,
    );
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final text = await _generate(
          system: system,
          user: user,
        ).timeout(timeout);
        final trimmed = text?.trim() ?? '';
        if (trimmed.isNotEmpty) {
          return Translation(text: trimmed, engine: kind);
        }
        lastError = StateError('empty translation');
      } on FirebaseAIException catch (e) {
        if (isRegionBlocked(e)) {
          rethrow;
        }
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('translation failed');
  }

  /// Whether Gemini refused the request because of the user's location (doc 03 §7).
  static bool isRegionBlocked(Object error) =>
      error.toString().contains('User location is not supported');
}

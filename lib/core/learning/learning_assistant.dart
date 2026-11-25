import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/generative_model_factory.dart';
import '../di/di.dart';
import 'learning_models.dart';
import 'learning_prompts.dart';

/// Sends a system instruction and a user message to Gemini and returns its JSON text.
typedef LearningGenerate = Future<String?> Function({
  required String system,
  required String user,
});

/// The online learning helpers: phrasing review, suggested replies and summaries (F-17, F-19, F-20).
abstract interface class LearningAssistant {
  /// Up to five user lines with a more natural version in [partnerLang] (AC-17.1).
  Future<List<PhrasingTip>> reviewPhrasing({
    required List<LearningLine> lines,
    required String userLang,
    required String partnerLang,
  });

  /// Three replies in [replyLang] with back-translations in [userLang] (AC-19.1).
  Future<List<SuggestedReply>> suggestReplies({
    required List<LearningLine> recent,
    required String replyLang,
    required String userLang,
  });

  /// Summary, key terms and action items in [userLang] (AC-20.1).
  Future<SessionRecap> summarize({
    required List<LearningLine> lines,
    required String userLang,
  });
}

/// [LearningAssistant] on Gemini (`model_text_review`) through Firebase AI Logic.
class GeminiLearningAssistant implements LearningAssistant {
  GeminiLearningAssistant(
    this._generate, {
    this.timeout = const Duration(seconds: 20),
    this.replyTimeout = const Duration(seconds: 8),
  });

  /// Builds the assistant on Firebase AI Logic with the Remote Config review model.
  factory GeminiLearningAssistant.firebase(GenerativeModelFactory factory) =>
      GeminiLearningAssistant(({required system, required user}) async {
        final response = await factory
            .reviewModel(systemInstruction: system)
            .generateContent([Content.text(user)]);
        return response.text;
      });

  final LearningGenerate _generate;
  final Duration timeout;
  final Duration replyTimeout;

  @override
  Future<List<PhrasingTip>> reviewPhrasing({
    required List<LearningLine> lines,
    required String userLang,
    required String partnerLang,
  }) async {
    final json = await _ask(
      LearningPrompts.reviewSystem(
        userLang: userLang,
        partnerLang: partnerLang,
      ),
      LearningPrompts.transcript(lines),
      timeout,
    );
    return [
      for (final item in _list(json, 'items'))
        if (_text(item, 'original') case final original?)
          if (_text(item, 'improved') case final improved?)
            PhrasingTip(
              original: original,
              improved: improved,
              reason: _text(item, 'reason') ?? '',
            ),
    ].take(LearningPrompts.maxTips).toList();
  }

  @override
  Future<List<SuggestedReply>> suggestReplies({
    required List<LearningLine> recent,
    required String replyLang,
    required String userLang,
  }) async {
    final last = recent.length > LearningPrompts.replyContext
        ? recent.sublist(recent.length - LearningPrompts.replyContext)
        : recent;
    final json = await _ask(
      LearningPrompts.repliesSystem(replyLang: replyLang, userLang: userLang),
      LearningPrompts.transcript(last),
      replyTimeout,
    );
    return [
      for (final item in _list(json, 'replies'))
        if (_text(item, 'text') case final text?)
          SuggestedReply(
            text: text,
            backTranslation: _text(item, 'back') ?? '',
          ),
    ].take(3).toList();
  }

  @override
  Future<SessionRecap> summarize({
    required List<LearningLine> lines,
    required String userLang,
  }) async {
    final json = await _ask(
      LearningPrompts.summarySystem(userLang: userLang),
      LearningPrompts.transcript(lines),
      timeout,
    );
    final summary = _text(json, 'summary');
    if (summary == null) {
      throw const FormatException('summary missing');
    }
    return SessionRecap(
      lang: userLang,
      summary: summary,
      keyTerms: [
        for (final term in _list(json, 'keyTerms'))
          if (term is String && term.trim().isNotEmpty) term.trim(),
      ],
      actionItems: [
        for (final item in _list(json, 'actionItems'))
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ],
    );
  }

  /// Asks Gemini and decodes the JSON object it answers with.
  Future<Map<String, Object?>> _ask(
    String system,
    String user,
    Duration limit,
  ) async {
    final text = await _generate(system: system, user: user).timeout(limit);
    return parseJsonObject(text ?? '');
  }

  /// Decodes the first JSON object in [text], ignoring code fences around it.
  static Map<String, Object?> parseJsonObject(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('no JSON object');
    }
    final value = jsonDecode(text.substring(start, end + 1));
    if (value is! Map<String, Object?>) {
      throw const FormatException('not a JSON object');
    }
    return value;
  }

  /// The list under [key], or empty.
  static List<Object?> _list(Map<String, Object?> json, String key) =>
      json[key] is List ? json[key]! as List<Object?> : const [];

  /// The trimmed non-empty string under [key] of [item], or null.
  static String? _text(Object? item, String key) {
    if (item is! Map) {
      return null;
    }
    final value = item[key];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}

/// The learning assistant.
final learningAssistantProvider = Provider<LearningAssistant>(
  (ref) => GeminiLearningAssistant.firebase(getIt<GenerativeModelFactory>()),
);

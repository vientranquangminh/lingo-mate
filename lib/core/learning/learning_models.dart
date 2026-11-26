import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../database/app_database.dart';

/// One transcript line given to the assistant.
class LearningLine extends Equatable {
  const LearningLine({
    required this.sourceLang,
    required this.sourceText,
    required this.targetLang,
    required this.targetText,
    this.speaker,
  });

  /// The line of a stored utterance.
  factory LearningLine.fromUtterance(Utterance u) => LearningLine(
    speaker: u.speaker,
    sourceLang: u.sourceLang,
    sourceText: u.sourceText,
    targetLang: u.targetLang,
    targetText: u.targetText,
  );

  final String? speaker;
  final String sourceLang;
  final String sourceText;
  final String targetLang;
  final String targetText;

  @override
  List<Object?> get props => [
    speaker,
    sourceLang,
    sourceText,
    targetLang,
    targetText,
  ];
}

/// "You said" → "A native speaker would say" with a one-line reason (F-17).
class PhrasingTip extends Equatable {
  const PhrasingTip({
    required this.original,
    required this.improved,
    required this.reason,
    this.meaning = '',
  });

  final String original;
  final String improved;
  final String reason;
  final String meaning;

  @override
  List<Object?> get props => [original, improved, reason, meaning];
}

/// A short reply in the partner's language with its back-translation (F-19).
class SuggestedReply extends Equatable {
  const SuggestedReply({required this.text, required this.backTranslation});

  final String text;
  final String backTranslation;

  @override
  List<Object?> get props => [text, backTranslation];
}

/// A session summary with key terms and action items, in the user's language (F-20).
class SessionRecap extends Equatable {
  const SessionRecap({
    required this.lang,
    required this.summary,
    this.keyTerms = const [],
    this.actionItems = const [],
  });

  final String lang;
  final String summary;
  final List<String> keyTerms;
  final List<String> actionItems;

  /// Encodes the summary for the sessions table.
  String encode() => jsonEncode({
    'lang': lang,
    'summary': summary,
    'keyTerms': keyTerms,
    'actionItems': actionItems,
  });

  /// Decodes a stored summary, or null when [value] is empty or unreadable.
  static SessionRecap? decode(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      final map = jsonDecode(value) as Map<String, Object?>;
      return SessionRecap(
        lang: map['lang'] as String? ?? 'en',
        summary: map['summary'] as String? ?? '',
        keyTerms: _strings(map['keyTerms']),
        actionItems: _strings(map['actionItems']),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Reads a JSON list of strings, skipping anything else.
  static List<String> _strings(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ]
      : const [];

  @override
  List<Object?> get props => [lang, summary, keyTerms, actionItems];
}

/// One message of a roleplay: from the learner or the AI partner, with feedback on learner messages (F-22).
class RoleplayMessage extends Equatable {
  const RoleplayMessage({
    required this.fromLearner,
    required this.text,
    this.translation,
    this.feedback,
  });

  final bool fromLearner;
  final String text;
  final String? translation;
  final PhrasingTip? feedback;

  /// Returns a copy with [feedback].
  RoleplayMessage withFeedback(PhrasingTip? feedback) => RoleplayMessage(
    fromLearner: fromLearner,
    text: text,
    translation: translation,
    feedback: feedback,
  );

  @override
  List<Object?> get props => [fromLearner, text, translation, feedback];
}

/// The partner's next line and feedback on the learner's last one.
class RoleplayTurn extends Equatable {
  const RoleplayTurn({
    required this.reply,
    required this.replyTranslation,
    this.feedback,
  });

  final String reply;
  final String replyTranslation;
  final PhrasingTip? feedback;

  @override
  List<Object?> get props => [reply, replyTranslation, feedback];
}

/// Rules for when the learning features are offered on a session.
abstract final class LearningRules {
  static const minUserLines = 3;
  static const minSummarySec = 180;

  /// The user's own translated lines of a Conversation session (speaker `a`).
  static List<Utterance> userLines(List<Utterance> utterances) => [
    for (final u in utterances)
      if (u.speaker == 'a' && u.targetText.isNotEmpty) u,
  ];

  /// Whether a session may ask for the post-session review (AC-17.1).
  static bool canReview(List<Utterance> utterances) =>
      userLines(utterances).length >= minUserLines;

  /// Whether a session may be summarised: Meeting or Listen, 3 minutes or longer (AC-20.1).
  static bool canSummarize(String mode, int durationSec) =>
      (mode == 'meeting' || mode == 'listen') && durationSec >= minSummarySec;

  /// The summary as plain text for sharing (AC-20.2).
  static String summaryText(
    SessionRecap recap, {
    required String title,
    required String keyTermsLabel,
    required String actionItemsLabel,
  }) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln(recap.summary);
    if (recap.keyTerms.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(keyTermsLabel);
      for (final term in recap.keyTerms) {
        buffer.writeln('• $term');
      }
    }
    if (recap.actionItems.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(actionItemsLabel);
      for (final item in recap.actionItems) {
        buffer.writeln('• $item');
      }
    }
    return buffer.toString().trimRight();
  }
}

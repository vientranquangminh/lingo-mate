import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';

/// The two people in a conversation: [a] is the user (bottom half), [b] the partner (top half).
enum Speaker {
  a,
  b;

  /// The other person.
  Speaker get other => this == a ? b : a;
}

/// How far an utterance has got through the pipeline.
enum TurnStatus { translating, translated, paused, failed }

/// One utterance: what was said, its translation and the engine that translated it.
class ConversationTurn extends Equatable {
  const ConversationTurn({
    required this.id,
    required this.speaker,
    required this.from,
    required this.to,
    required this.original,
    this.translation,
    this.engine,
    this.fallback = false,
    this.status = TurnStatus.translating,
  });

  final int id;
  final Speaker speaker;
  final String from;
  final String to;
  final String original;
  final String? translation;
  final EngineKind? engine;
  final bool fallback;
  final TurnStatus status;

  ConversationTurn copyWith({
    String? translation,
    EngineKind? engine,
    bool? fallback,
    TurnStatus? status,
  }) {
    return ConversationTurn(
      id: id,
      speaker: speaker,
      from: from,
      to: to,
      original: original,
      translation: translation ?? this.translation,
      engine: engine ?? this.engine,
      fallback: fallback ?? this.fallback,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    speaker,
    from,
    to,
    original,
    translation,
    engine,
    fallback,
    status,
  ];
}

/// Why translation stopped (AC-02.8).
enum PauseReason { noEngine, noSpeechModel, micDenied }

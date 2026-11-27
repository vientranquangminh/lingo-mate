import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';

/// How far a meeting line has got through the pipeline.
enum MeetingLineStatus { translating, translated, paused, failed }

/// Why Meeting cannot caption, with the action that fixes it.
enum MeetingBlock { noEngine, noSpeechModel, micDenied }

/// One meeting line; [newTurn] marks a long pause before it, shown as a speaker change (no diarization in P1).
class MeetingLine extends Equatable {
  const MeetingLine({
    required this.id,
    required this.from,
    required this.to,
    required this.original,
    required this.atMs,
    this.newTurn = false,
    this.speaker,
    this.translation,
    this.engine,
    this.fallback = false,
    this.status = MeetingLineStatus.translating,
  });

  final int id;
  final String from;
  final String to;
  final String original;
  final int atMs;
  final bool newTurn;
  final int? speaker;
  final String? translation;
  final EngineKind? engine;
  final bool fallback;
  final MeetingLineStatus status;

  /// The text shown as the translation: the translation once there, else the original.
  String get shown => translation ?? original;

  MeetingLine copyWith({
    String? original,
    String? translation,
    EngineKind? engine,
    bool? fallback,
    MeetingLineStatus? status,
  }) {
    return MeetingLine(
      id: id,
      from: from,
      to: to,
      original: original ?? this.original,
      atMs: atMs,
      newTurn: newTurn,
      speaker: speaker,
      translation: translation ?? this.translation,
      engine: engine ?? this.engine,
      fallback: fallback ?? this.fallback,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    id,
    from,
    to,
    original,
    atMs,
    newTurn,
    speaker,
    translation,
    engine,
    fallback,
    status,
  ];
}

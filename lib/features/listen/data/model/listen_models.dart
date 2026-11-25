import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';

/// The source code that asks Listen to detect the speaker's language.
const listenAutoSource = 'auto';

/// How far a caption has got through the pipeline.
enum CaptionStatus { translating, translated, paused, failed }

/// Why captions stopped, with the action that fixes it.
enum ListenBlock { noEngine, noSpeechModel, micDenied }

/// One caption: what the speaker said, its translation and when, from the session start.
class Caption extends Equatable {
  const Caption({
    required this.id,
    required this.from,
    required this.to,
    required this.original,
    required this.atMs,
    this.translation,
    this.engine,
    this.fallback = false,
    this.status = CaptionStatus.translating,
  });

  final int id;
  final String from;
  final String to;
  final String original;
  final int atMs;
  final String? translation;
  final EngineKind? engine;
  final bool fallback;
  final CaptionStatus status;

  Caption copyWith({
    String? translation,
    EngineKind? engine,
    bool? fallback,
    CaptionStatus? status,
  }) {
    return Caption(
      id: id,
      from: from,
      to: to,
      original: original,
      atMs: atMs,
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
    translation,
    engine,
    fallback,
    status,
  ];
}

import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';

/// One clip from `manifest.json` (doc 00 §5).
class BenchmarkClip extends Equatable {
  const BenchmarkClip({
    required this.id,
    required this.file,
    required this.lang,
    required this.scenario,
    this.referenceTranscript = '',
    this.referenceTranslation = const {},
  });

  /// Builds a clip from one manifest entry.
  factory BenchmarkClip.fromJson(Map<String, dynamic> json) => BenchmarkClip(
    id: json['id'] as String,
    file: json['file'] as String,
    lang: json['lang'] as String,
    scenario: json['scenario'] as String? ?? '',
    referenceTranscript: json['reference_transcript'] as String? ?? '',
    referenceTranslation:
        (json['reference_translation'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as String),
        ),
  );

  final String id;
  final String file;
  final String lang;
  final String scenario;
  final String referenceTranscript;
  final Map<String, String> referenceTranslation;

  @override
  List<Object?> get props => [id, file, lang];
}

/// An ASR engine optionally followed by a translator, run as one benchmark pipeline.
class BenchmarkPipeline extends Equatable {
  const BenchmarkPipeline({
    required this.asr,
    this.translator,
    this.targetLang,
  });

  final SpeechRecognizerEngine asr;
  final TextTranslatorEngine? translator;
  final String? targetLang;

  /// Returns the language to translate a clip into: [targetLang], else Vietnamese for English clips and English otherwise.
  String targetFor(String clipLang) =>
      targetLang ?? (clipLang == 'en' ? 'vi' : 'en');

  String get id => translator == null ? asr.id : '${asr.id}+${translator!.id}';

  @override
  List<Object?> get props => [id, targetLang];
}

/// One utterance result written to the benchmark CSV.
class BenchmarkRow extends Equatable {
  const BenchmarkRow({
    required this.clipId,
    required this.lang,
    required this.pipeline,
    required this.utterance,
    required this.segmentStartMs,
    required this.segmentEndMs,
    this.asrMs,
    this.translationMs,
    this.transcript = '',
    this.translation = '',
    this.targetLang = '',
    this.referenceTranscript = '',
    this.referenceTranslation = '',
    this.error = '',
  });

  static const header = [
    'clip',
    'lang',
    'pipeline',
    'utterance',
    'segment_start_ms',
    'segment_end_ms',
    'asr_ms',
    'translation_ms',
    'transcript',
    'target_lang',
    'translation',
    'reference_transcript',
    'reference_translation',
    'error',
  ];

  final String clipId;
  final String lang;
  final String pipeline;
  final int utterance;
  final int segmentStartMs;
  final int segmentEndMs;
  final int? asrMs;
  final int? translationMs;
  final String transcript;
  final String translation;
  final String targetLang;
  final String referenceTranscript;
  final String referenceTranslation;
  final String error;

  /// Returns the row's values in [header] order.
  List<Object?> toCells() => [
    clipId,
    lang,
    pipeline,
    utterance,
    segmentStartMs,
    segmentEndMs,
    asrMs,
    translationMs,
    transcript,
    targetLang,
    translation,
    referenceTranscript,
    referenceTranslation,
    error,
  ];

  @override
  List<Object?> get props => toCells();
}

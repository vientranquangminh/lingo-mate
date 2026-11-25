import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/phrases/phrase_repository.dart';
import '../../../../core/review/review_settings.dart';
import '../../../../core/sessions/session_repository.dart';

/// The Me stats: time translated, phrases saved and review streak (AC-13.7).
class MeStats extends Equatable {
  const MeStats({
    this.translatedSec = 0,
    this.phrasesSaved = 0,
    this.streakDays = 0,
  });

  final int translatedSec;
  final int phrasesSaved;
  final int streakDays;

  @override
  List<Object?> get props => [translatedSec, phrasesSaved, streakDays];
}

/// Seconds translated in all sessions.
final translatedSecondsProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(sessionRepositoryProvider).watchTotalSeconds(),
);

/// Phrases in the phrasebook.
final savedPhrasesProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(phraseRepositoryProvider).watchCount(),
);

/// The Me stats, computed locally.
final meStatsProvider = Provider.autoDispose<MeStats>(
  (ref) => MeStats(
    translatedSec: ref.watch(translatedSecondsProvider).value ?? 0,
    phrasesSaved: ref.watch(savedPhrasesProvider).value ?? 0,
    streakDays: ref.watch(
      reviewSettingsProvider.select((s) => s.streakOn(DateTime.now())),
    ),
  ),
);

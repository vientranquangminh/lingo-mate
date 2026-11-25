import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/phrases/phrase_repository.dart';

/// Phrases matching a filter (AC-08.4).
final phrasesProvider = StreamProvider.autoDispose
    .family<List<PhraseItem>, PhraseFilter>(
      (ref, filter) => ref.watch(phraseRepositoryProvider).watch(filter),
    );

/// Language pairs present, for the filter chips.
final phrasePairsProvider = StreamProvider.autoDispose<List<LanguagePair>>(
  (ref) => ref.watch(phraseRepositoryProvider).watchPairs(),
);

/// Tags in use, for the filter chips.
final phraseTagsProvider = StreamProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(phraseRepositoryProvider).watchTags(),
);

/// Number of phrases, for the search hint.
final phraseCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(phraseRepositoryProvider).watchCount(),
);

/// One phrase for the detail screen.
final phraseProvider = StreamProvider.autoDispose.family<PhraseItem?, String>(
  (ref, id) => ref.watch(phraseRepositoryProvider).watchOne(id),
);

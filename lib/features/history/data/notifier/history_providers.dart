import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sessions/session_repository.dart';

/// Finished sessions, newest first (AC-07.1).
final historySessionsProvider =
    StreamProvider.autoDispose<List<SessionSummary>>(
      (ref) => ref.watch(sessionRepositoryProvider).watchSessions(),
    );

/// Utterances matching a search of at least 2 characters (AC-07.3).
final historySearchProvider = FutureProvider.autoDispose
    .family<List<SearchHit>, String>(
      (ref, query) => ref.watch(sessionRepositoryProvider).search(query),
    );

/// One session with its utterances; reloaded after a rename.
final transcriptProvider = FutureProvider.autoDispose
    .family<SessionDetail?, String>(
      (ref, id) => ref.watch(sessionRepositoryProvider).load(id),
    );

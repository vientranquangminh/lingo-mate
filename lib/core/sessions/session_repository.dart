import 'dart:math';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../di/di.dart';
import '../engines/engines.dart';
import '../engines/selection/engine_selector.dart';

/// How an utterance was translated, as stored in `utterances.engine` (doc 03 §6.2).
enum UtteranceEngine {
  offline,
  standard,
  live,
  offlineFallback,
  none;

  /// The stored value.
  String get value => switch (this) {
    offlineFallback => 'offline_fallback',
    _ => name,
  };

  /// Parses a stored value, treating unknown values as [none].
  static UtteranceEngine parse(String value) =>
      values.where((e) => e.value == value).firstOrNull ?? none;

  /// Returns the stored engine for a translation by [kind], marking an Offline fallback.
  static UtteranceEngine of(EngineKind? kind, {bool fallback = false}) =>
      switch (kind) {
        null => none,
        EngineKind.offline when fallback => offlineFallback,
        EngineKind.offline => offline,
        EngineKind.standard => standard,
        EngineKind.live => live,
      };

  /// The engine that did the work; a fallback counts as Offline.
  EngineKind? get kind => switch (this) {
    offline || offlineFallback => EngineKind.offline,
    standard => EngineKind.standard,
    live => EngineKind.live,
    none => null,
  };
}

/// An utterance to add to a session.
class NewUtterance extends Equatable {
  const NewUtterance({
    required this.speaker,
    required this.sourceLang,
    required this.sourceText,
    required this.targetLang,
    required this.targetText,
    required this.startMs,
    required this.endMs,
    required this.engine,
    this.latencyMs,
  });

  final String? speaker;
  final String sourceLang;
  final String sourceText;
  final String targetLang;
  final String targetText;
  final int startMs;
  final int endMs;
  final UtteranceEngine engine;
  final int? latencyMs;

  @override
  List<Object?> get props => [
    speaker,
    sourceLang,
    sourceText,
    targetLang,
    targetText,
    startMs,
    endMs,
    engine,
    latencyMs,
  ];
}

/// A finished session as the history lists it, with its first translated line.
class SessionSummary extends Equatable {
  const SessionSummary({required this.session, required this.firstLine});

  final Session session;
  final String? firstLine;

  @override
  List<Object?> get props => [session, firstLine];
}

/// A session with all of its utterances in order.
class SessionDetail extends Equatable {
  const SessionDetail({required this.session, required this.utterances});

  final Session session;
  final List<Utterance> utterances;

  /// Seconds of utterance audio per engine; fallbacks count as Offline.
  Map<EngineKind, int> get engineSeconds {
    final ms = <EngineKind, int>{};
    for (final u in utterances) {
      final kind = UtteranceEngine.parse(u.engine).kind;
      if (kind != null) {
        ms[kind] = (ms[kind] ?? 0) + (u.endMs - u.startMs);
      }
    }
    return {for (final e in ms.entries) e.key: (e.value / 1000).round()};
  }

  /// The engine that translated most of the session, else the one it started on.
  EngineKind? get mainEngine {
    final counts = <EngineKind, int>{};
    for (final u in utterances) {
      final kind = UtteranceEngine.parse(u.engine).kind;
      if (kind != null) {
        counts[kind] = (counts[kind] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return UtteranceEngine.parse(session.engineInitial).kind;
    }
    return (counts.entries.toList()..sort((a, b) => b.value - a.value))
        .first
        .key;
  }

  @override
  List<Object?> get props => [session, utterances];
}

/// An utterance that matched a search, with its session.
class SearchHit extends Equatable {
  const SearchHit({required this.utterance, required this.session});

  final Utterance utterance;
  final Session session;

  @override
  List<Object?> get props => [utterance, session];
}

/// The local database.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => getIt<AppDatabase>(),
);

/// Sessions and transcripts.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(appDatabaseProvider)),
);

/// Saves sessions and their utterances locally, lists, searches, renames and deletes them (F-07). Never stores audio.
class SessionRepository {
  SessionRepository(this._db, {DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  static const titleLength = 60;

  final AppDatabase _db;
  final DateTime Function() _now;
  final Random _random;

  /// Returns a random 128-bit id as hex.
  String _newId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Starts a session and returns its id.
  Future<String> start({
    required SessionMode mode,
    required EngineKind? engine,
    required LanguagePair pair,
  }) async {
    final id = _newId();
    await _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: id,
            mode: mode.name,
            engineInitial: UtteranceEngine.of(engine).value,
            langA: pair.a,
            langB: pair.b,
            startedAt: _now(),
          ),
        );
    return id;
  }

  /// Adds one utterance to session [sessionId]; returns its id.
  Future<String> addUtterance(String sessionId, NewUtterance utterance) async {
    final id = _newId();
    await _db
        .into(_db.utterances)
        .insert(
          UtterancesCompanion.insert(
            id: id,
            sessionId: sessionId,
            speaker: Value(utterance.speaker),
            sourceLang: utterance.sourceLang,
            sourceText: utterance.sourceText,
            targetLang: utterance.targetLang,
            targetText: utterance.targetText,
            startMs: utterance.startMs,
            endMs: utterance.endMs,
            engine: utterance.engine.value,
            latencyMs: Value(utterance.latencyMs),
          ),
        );
    await _meter(sessionId, utterance);
    return id;
  }

  /// Writes the cloud seconds of [utterance] to the usage ledger; Offline is never metered (doc 03 §10).
  Future<void> _meter(String sessionId, NewUtterance utterance) async {
    final engine = switch (utterance.engine) {
      UtteranceEngine.standard => EngineKind.standard,
      UtteranceEngine.live => EngineKind.live,
      _ => null,
    };
    if (engine == null) {
      return;
    }
    final seconds = max(
      1,
      ((utterance.endMs - utterance.startMs) / 1000).ceil(),
    );
    await _db
        .into(_db.usageLedger)
        .insert(
          UsageLedgerCompanion.insert(
            engine: engine.name,
            seconds: seconds,
            at: _now(),
            sessionId: Value(sessionId),
          ),
        );
  }

  /// Ends session [id]: sets duration, metered seconds and the auto title; a session with no utterances is removed.
  Future<void> finish(String id) async {
    final detail = await load(id);
    if (detail == null) {
      return;
    }
    if (detail.utterances.isEmpty) {
      await delete(id);
      return;
    }
    final ended = _now();
    final seconds = detail.engineSeconds;
    await (_db.update(_db.sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(
        endedAt: Value(ended),
        durationSec: Value(
          ended.difference(detail.session.startedAt).inSeconds,
        ),
        standardSec: Value(seconds[EngineKind.standard] ?? 0),
        liveSec: Value(seconds[EngineKind.live] ?? 0),
        title: detail.session.title == null
            ? Value(_autoTitle(detail.utterances))
            : const Value.absent(),
      ),
    );
  }

  /// Returns the first translated sentence, shortened, as the title (F-07).
  static String? _autoTitle(List<Utterance> utterances) {
    final first = utterances
        .map((u) => u.targetText.trim())
        .where((t) => t.isNotEmpty)
        .firstOrNull;
    if (first == null) {
      return null;
    }
    final sentence = first.split(RegExp(r'(?<=[.!?。！？])\s')).first;
    return sentence.length <= titleLength
        ? sentence
        : '${sentence.substring(0, titleLength - 1).trimRight()}…';
  }

  /// Finished sessions, newest first, each with its first translated line (AC-07.1).
  Stream<List<SessionSummary>> watchSessions() {
    final first = _db.utterances.targetText;
    final query =
        _db.select(_db.sessions).join([
            leftOuterJoin(
              _db.utterances,
              _db.utterances.id.equalsExp(
                subqueryExpression<String>(
                  _db.selectOnly(_db.utterances)
                    ..addColumns([_db.utterances.id])
                    ..where(
                      _db.utterances.sessionId.equalsExp(_db.sessions.id) &
                          _db.utterances.targetText.isNotValue(''),
                    )
                    ..orderBy([OrderingTerm.asc(_db.utterances.startMs)])
                    ..limit(1),
                ),
              ),
            ),
          ])
          ..where(_db.sessions.endedAt.isNotNull())
          ..orderBy([OrderingTerm.desc(_db.sessions.startedAt)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          SessionSummary(
            session: row.readTable(_db.sessions),
            firstLine: row.read(first),
          ),
      ],
    );
  }

  /// Returns session [id] with its utterances in time order, or null when it is gone.
  Future<SessionDetail?> load(String id) async {
    final session = await (_db.select(
      _db.sessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null) {
      return null;
    }
    final utterances =
        await (_db.select(_db.utterances)
              ..where((u) => u.sessionId.equals(id))
              ..orderBy([(u) => OrderingTerm.asc(u.startMs)]))
            .get();
    return SessionDetail(session: session, utterances: utterances);
  }

  /// Finds utterances whose original or translation contains every word of [query] as a prefix, ignoring accents (AC-07.3).
  Future<List<SearchHit>> search(String query, {int limit = 50}) async {
    final match = ftsQuery(query);
    if (match == null) {
      return const [];
    }
    final rows = await _db
        .customSelect(
          'SELECT u.id FROM utterances_fts f '
          'JOIN utterances u ON u.rowid = f.rowid '
          'WHERE utterances_fts MATCH ? ORDER BY rank LIMIT ?',
          variables: [Variable.withString(match), Variable.withInt(limit)],
          readsFrom: {_db.utterances},
        )
        .get();
    final ids = [for (final r in rows) r.read<String>('id')];
    if (ids.isEmpty) {
      return const [];
    }
    final joined = await (_db.select(_db.utterances).join([
      innerJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.utterances.sessionId),
      ),
    ])..where(_db.utterances.id.isIn(ids))).get();
    final byId = {
      for (final row in joined)
        row.readTable(_db.utterances).id: SearchHit(
          utterance: row.readTable(_db.utterances),
          session: row.readTable(_db.sessions),
        ),
    };
    return [for (final id in ids) ?byId[id]];
  }

  /// Turns user text into an FTS5 query of quoted prefix terms; null when shorter than 2 characters.
  static String? ftsQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return null;
    }
    final terms = trimmed
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll('"', ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*');
    return terms.isEmpty ? null : terms.join(' ');
  }

  /// Renames session [id].
  Future<void> rename(String id, String title) async {
    final trimmed = title.trim();
    await (_db.update(_db.sessions)..where((s) => s.id.equals(id))).write(
      SessionsCompanion(title: Value(trimmed.isEmpty ? null : trimmed)),
    );
  }

  /// Deletes session [id] and, by cascade, its utterances (AC-07.4).
  Future<void> delete(String id) =>
      (_db.delete(_db.sessions)..where((s) => s.id.equals(id))).go();

  /// Total seconds of finished sessions, for the Me stats (AC-13.7).
  Stream<int> watchTotalSeconds() {
    final total = _db.sessions.durationSec.sum();
    final query = _db.selectOnly(_db.sessions)..addColumns([total]);
    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Stores the encoded summary of session [id] (AC-20.1).
  Future<void> saveSummary(String id, String summary) =>
      (_db.update(_db.sessions)..where((s) => s.id.equals(id))).write(
        SessionsCompanion(summary: Value(summary)),
      );

  /// Returns the transcript as plain text: the title, then original and translation per line (AC-07.5).
  static String plainText(SessionDetail detail, {String? title}) {
    final buffer = StringBuffer();
    final heading = title ?? detail.session.title;
    if (heading != null) {
      buffer
        ..writeln(heading)
        ..writeln();
    }
    for (final u in detail.utterances) {
      buffer.writeln(u.sourceText);
      if (u.targetText.isNotEmpty) {
        buffer.writeln(u.targetText);
      }
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}

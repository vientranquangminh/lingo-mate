import 'dart:math';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../engines/selection/engine_selector.dart';
import '../sessions/session_repository.dart';

/// Which phrases a list shows (AC-08.4).
class PhraseFilter extends Equatable {
  const PhraseFilter({
    this.pair,
    this.tagId,
    this.favoritesOnly = false,
    this.query = '',
  });

  final LanguagePair? pair;
  final String? tagId;
  final bool favoritesOnly;
  final String query;

  PhraseFilter copyWith({
    LanguagePair? Function()? pair,
    String? Function()? tagId,
    bool? favoritesOnly,
    String? query,
  }) {
    return PhraseFilter(
      pair: pair != null ? pair() : this.pair,
      tagId: tagId != null ? tagId() : this.tagId,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [pair, tagId, favoritesOnly, query];
}

/// A phrase with its tags and the session it was saved from.
class PhraseItem extends Equatable {
  const PhraseItem({
    required this.phrase,
    this.tags = const [],
    this.sessionId,
    this.sessionTitle,
    this.spokenAt,
  });

  final Phrase phrase;
  final List<Tag> tags;
  final String? sessionId;
  final String? sessionTitle;
  final DateTime? spokenAt;

  @override
  List<Object?> get props => [phrase, tags, sessionId, sessionTitle, spokenAt];
}

/// Whether a save added a phrase or found it already there (AC-08.2).
enum SaveOutcome { saved, duplicate }

/// The result of saving a phrase.
class SaveResult extends Equatable {
  const SaveResult(this.outcome, this.id);

  final SaveOutcome outcome;
  final String id;

  @override
  List<Object?> get props => [outcome, id];
}

/// Phrases.
final phraseRepositoryProvider = Provider<PhraseRepository>(
  (ref) => PhraseRepository(ref.watch(appDatabaseProvider)),
);

/// The personal phrasebook: save with de-duplication, filter, tag, favourite, edit and soft delete (F-08).
class PhraseRepository {
  PhraseRepository(this._db, {DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  final AppDatabase _db;
  final DateTime Function() _now;
  final Random _random;

  /// Returns a random 128-bit id as hex.
  String _newId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Saves a phrase unless one with the same source text and language pair exists (AC-08.1, AC-08.2).
  Future<SaveResult> save({
    required String sourceLang,
    required String sourceText,
    required String targetLang,
    required String targetText,
    String? fromUtteranceId,
    String? note,
  }) async {
    final source = sourceText.trim();
    final existing =
        await (_db.select(_db.phrases)
              ..where(
                (p) =>
                    p.sourceLang.equals(sourceLang) &
                    p.targetLang.equals(targetLang) &
                    p.sourceText.equals(source) &
                    p.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    await _markSaved(fromUtteranceId);
    if (existing != null) {
      return SaveResult(SaveOutcome.duplicate, existing.id);
    }
    final id = _newId();
    final now = _now();
    await _db
        .into(_db.phrases)
        .insert(
          PhrasesCompanion.insert(
            id: id,
            sourceLang: sourceLang,
            sourceText: source,
            targetLang: targetLang,
            targetText: targetText.trim(),
            note: Value(note),
            fromUtteranceId: Value(fromUtteranceId),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return SaveResult(SaveOutcome.saved, id);
  }

  /// Flags the utterance a phrase came from as saved.
  Future<void> _markSaved(String? utteranceId) async {
    if (utteranceId == null) {
      return;
    }
    await (_db.update(_db.utterances)..where((u) => u.id.equals(utteranceId)))
        .write(const UtterancesCompanion(isSaved: Value(true)));
  }

  /// Phrases matching [filter], newest first, with tags and source session (AC-08.1, AC-08.4).
  Stream<List<PhraseItem>> watch(PhraseFilter filter) {
    final query = _db.select(_db.phrases).join([
      leftOuterJoin(
        _db.utterances,
        _db.utterances.id.equalsExp(_db.phrases.fromUtteranceId),
      ),
      leftOuterJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.utterances.sessionId),
      ),
    ]);
    var where = _db.phrases.deletedAt.isNull();
    final pair = filter.pair;
    if (pair != null) {
      where =
          where &
          ((_db.phrases.sourceLang.equals(pair.a) &
                  _db.phrases.targetLang.equals(pair.b)) |
              (_db.phrases.sourceLang.equals(pair.b) &
                  _db.phrases.targetLang.equals(pair.a)));
    }
    if (filter.favoritesOnly) {
      where = where & _db.phrases.favorite.equals(true);
    }
    final tagId = filter.tagId;
    if (tagId != null) {
      where =
          where &
          _db.phrases.id.isInQuery(
            _db.selectOnly(_db.phraseTags)
              ..addColumns([_db.phraseTags.phraseId])
              ..where(_db.phraseTags.tagId.equals(tagId)),
          );
    }
    final match = SessionRepository.ftsQuery(filter.query);
    if (match != null) {
      final literal = match.replaceAll("'", "''");
      where =
          where &
          CustomExpression<bool>(
            'phrases.rowid IN (SELECT rowid FROM phrases_fts '
            "WHERE phrases_fts MATCH '$literal')",
          );
    }
    query
      ..where(where)
      ..orderBy([OrderingTerm.desc(_db.phrases.createdAt)]);
    return query.watch().asyncMap((rows) async {
      final ids = [for (final r in rows) r.readTable(_db.phrases).id];
      final tags = await _tagsOf(ids);
      return [
        for (final row in rows)
          _item(row, tags[row.readTable(_db.phrases).id] ?? const []),
      ];
    });
  }

  /// Builds an item from a joined row.
  PhraseItem _item(TypedResult row, List<Tag> tags) {
    final phrase = row.readTable(_db.phrases);
    final utterance = row.readTableOrNull(_db.utterances);
    final session = row.readTableOrNull(_db.sessions);
    return PhraseItem(
      phrase: phrase,
      tags: tags,
      sessionId: session?.id,
      sessionTitle: session?.title,
      spokenAt: session == null || utterance == null
          ? null
          : session.startedAt.add(Duration(milliseconds: utterance.startMs)),
    );
  }

  /// Returns the tags of each phrase in [ids], by name.
  Future<Map<String, List<Tag>>> _tagsOf(List<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    final rows =
        await (_db.select(_db.phraseTags).join([
                innerJoin(
                  _db.tags,
                  _db.tags.id.equalsExp(_db.phraseTags.tagId),
                ),
              ])
              ..where(_db.phraseTags.phraseId.isIn(ids))
              ..orderBy([OrderingTerm.asc(_db.tags.name)]))
            .get();
    final map = <String, List<Tag>>{};
    for (final row in rows) {
      map
          .putIfAbsent(row.readTable(_db.phraseTags).phraseId, () => [])
          .add(row.readTable(_db.tags));
    }
    return map;
  }

  /// One phrase with its tags and source, or null once deleted.
  Stream<PhraseItem?> watchOne(String id) {
    final query = _db.select(_db.phrases).join([
      leftOuterJoin(
        _db.utterances,
        _db.utterances.id.equalsExp(_db.phrases.fromUtteranceId),
      ),
      leftOuterJoin(
        _db.sessions,
        _db.sessions.id.equalsExp(_db.utterances.sessionId),
      ),
    ])..where(_db.phrases.id.equals(id) & _db.phrases.deletedAt.isNull());
    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) {
        return null;
      }
      return _item(row, (await _tagsOf([id]))[id] ?? const []);
    });
  }

  /// Language pairs present in the phrasebook, each once whatever the direction.
  Stream<List<LanguagePair>> watchPairs() {
    final query = _db.selectOnly(_db.phrases, distinct: true)
      ..addColumns([_db.phrases.sourceLang, _db.phrases.targetLang])
      ..where(_db.phrases.deletedAt.isNull());
    return query.watch().map((rows) {
      final seen = <String>{};
      final pairs = <LanguagePair>[];
      for (final row in rows) {
        final a = row.read(_db.phrases.sourceLang)!;
        final b = row.read(_db.phrases.targetLang)!;
        final key = ([a, b]..sort()).join('|');
        if (seen.add(key)) {
          pairs.add(LanguagePair(a, b));
        }
      }
      return pairs;
    });
  }

  /// Tags in use, by name.
  Stream<List<Tag>> watchTags() => (_db.select(
    _db.tags,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  /// Number of phrases not deleted.
  Stream<int> watchCount() {
    final count = _db.phrases.id.count();
    final query = _db.selectOnly(_db.phrases)
      ..addColumns([count])
      ..where(_db.phrases.deletedAt.isNull());
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// Edits the translation or note of phrase [id].
  Future<void> edit(String id, {String? targetText, String? note}) =>
      (_db.update(_db.phrases)..where((p) => p.id.equals(id))).write(
        PhrasesCompanion(
          targetText: targetText == null
              ? const Value.absent()
              : Value(targetText.trim()),
          note: note == null
              ? const Value.absent()
              : Value(note.trim().isEmpty ? null : note.trim()),
          updatedAt: Value(_now()),
        ),
      );

  /// Stars or unstars phrase [id].
  Future<void> setFavorite(String id, bool favorite) =>
      (_db.update(_db.phrases)..where((p) => p.id.equals(id))).write(
        PhrasesCompanion(favorite: Value(favorite), updatedAt: Value(_now())),
      );

  /// Adds tag [name] to phrase [id], creating the tag when new.
  Future<void> addTag(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.tags,
      )..where((t) => t.name.equals(trimmed))).getSingleOrNull();
      final tagId = existing?.id ?? _newId();
      if (existing == null) {
        await _db
            .into(_db.tags)
            .insert(TagsCompanion.insert(id: tagId, name: trimmed));
      }
      await _db
          .into(_db.phraseTags)
          .insertOnConflictUpdate(
            PhraseTagsCompanion.insert(phraseId: id, tagId: tagId),
          );
      await _touch(id);
    });
  }

  /// Removes tag [tagId] from phrase [id]; a tag no phrase uses any more is dropped.
  Future<void> removeTag(String id, String tagId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.phraseTags,
      )..where((pt) => pt.phraseId.equals(id) & pt.tagId.equals(tagId))).go();
      final used = await (_db.select(
        _db.phraseTags,
      )..where((pt) => pt.tagId.equals(tagId))).get();
      if (used.isEmpty) {
        await (_db.delete(_db.tags)..where((t) => t.id.equals(tagId))).go();
      }
      await _touch(id);
    });
  }

  /// Marks phrase [id] changed so lists showing its tags refresh.
  Future<void> _touch(String id) =>
      (_db.update(_db.phrases)..where((p) => p.id.equals(id))).write(
        PhrasesCompanion(updatedAt: Value(_now())),
      );

  /// Hides phrase [id] by setting deleted_at, keeping the row for sync (AC-08.6).
  Future<void> softDelete(String id) =>
      (_db.update(_db.phrases)..where((p) => p.id.equals(id))).write(
        PhrasesCompanion(deletedAt: Value(_now()), updatedAt: Value(_now())),
      );

  /// Brings back a soft-deleted phrase (Undo, AC-08.6).
  Future<void> restore(String id) =>
      (_db.update(_db.phrases)..where((p) => p.id.equals(id))).write(
        PhrasesCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(_now()),
        ),
      );
}

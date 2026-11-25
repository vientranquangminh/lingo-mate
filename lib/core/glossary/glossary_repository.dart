import 'dart:math';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../sessions/session_repository.dart';

/// A glossary set with how many terms it holds.
class GlossarySetSummary extends Equatable {
  const GlossarySetSummary({required this.set, required this.termCount});

  final GlossarySet set;
  final int termCount;

  @override
  List<Object?> get props => [set, termCount];
}

/// Glossaries.
final glossaryRepositoryProvider = Provider<GlossaryRepository>(
  (ref) => GlossaryRepository(ref.watch(appDatabaseProvider)),
);

/// Glossary sets and terms; the active set feeds Standard translations (F-18).
class GlossaryRepository {
  GlossaryRepository(this._db, {DateTime Function()? now, Random? random})
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

  /// Sets by name with their term counts.
  Stream<List<GlossarySetSummary>> watchSets() {
    final count = _db.glossaryTerms.id.count();
    final query =
        _db.select(_db.glossarySets).join([
            leftOuterJoin(
              _db.glossaryTerms,
              _db.glossaryTerms.setId.equalsExp(_db.glossarySets.id) &
                  _db.glossaryTerms.deletedAt.isNull(),
              useColumns: false,
            ),
          ])
          ..addColumns([count])
          ..where(_db.glossarySets.deletedAt.isNull())
          ..groupBy([_db.glossarySets.id])
          ..orderBy([OrderingTerm.asc(_db.glossarySets.name)]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          GlossarySetSummary(
            set: row.readTable(_db.glossarySets),
            termCount: row.read(count) ?? 0,
          ),
      ],
    );
  }

  /// One set, or null once deleted.
  Stream<GlossarySet?> watchSet(String id) => (_db.select(
    _db.glossarySets,
  )..where((s) => s.id.equals(id) & s.deletedAt.isNull())).watchSingleOrNull();

  /// Terms of set [setId], alphabetically.
  Stream<List<GlossaryTerm>> watchTerms(String setId) =>
      (_db.select(_db.glossaryTerms)
            ..where((t) => t.setId.equals(setId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.term)]))
          .watch();

  /// Creates a set named [name] and returns its id.
  Future<String> createSet(String name) async {
    final id = _newId();
    await _db
        .into(_db.glossarySets)
        .insert(
          GlossarySetsCompanion.insert(
            id: id,
            name: name.trim(),
            createdAt: _now(),
            updatedAt: Value(_now()),
          ),
        );
    return id;
  }

  /// Renames set [id].
  Future<void> renameSet(String id, String name) =>
      (_db.update(_db.glossarySets)..where((s) => s.id.equals(id))).write(
        GlossarySetsCompanion(
          name: Value(name.trim()),
          updatedAt: Value(_now()),
        ),
      );

  /// Deletes set [id] with its terms, keeping tombstones so the delete syncs.
  Future<void> deleteSet(String id) => _db.transaction(() async {
    final gone = GlossaryTermsCompanion(
      deletedAt: Value(_now()),
      updatedAt: Value(_now()),
    );
    await (_db.update(
      _db.glossaryTerms,
    )..where((t) => t.setId.equals(id) & t.deletedAt.isNull())).write(gone);
    await (_db.update(_db.glossarySets)..where((s) => s.id.equals(id))).write(
      GlossarySetsCompanion(
        deletedAt: Value(_now()),
        updatedAt: Value(_now()),
        active: const Value(false),
      ),
    );
  });

  /// Makes set [id] the one used in sessions, or turns it off; at most one set is active (AC-18.1).
  Future<void> setActive(String id, bool active) => _db.transaction(() async {
    if (active) {
      await _db
          .update(_db.glossarySets)
          .write(const GlossarySetsCompanion(active: Value(false)));
    }
    await (_db.update(_db.glossarySets)..where((s) => s.id.equals(id))).write(
      GlossarySetsCompanion(active: Value(active)),
    );
  });

  /// Adds a term to set [setId].
  Future<String> addTerm(
    String setId, {
    required String term,
    required String translation,
    String? note,
  }) async {
    final id = _newId();
    await _db
        .into(_db.glossaryTerms)
        .insert(
          GlossaryTermsCompanion.insert(
            id: id,
            setId: setId,
            term: term.trim(),
            translation: translation.trim(),
            note: Value(_blankToNull(note)),
            createdAt: _now(),
            updatedAt: Value(_now()),
          ),
        );
    return id;
  }

  /// Changes term [id].
  Future<void> editTerm(
    String id, {
    required String term,
    required String translation,
    String? note,
  }) => (_db.update(_db.glossaryTerms)..where((t) => t.id.equals(id))).write(
    GlossaryTermsCompanion(
      term: Value(term.trim()),
      translation: Value(translation.trim()),
      note: Value(_blankToNull(note)),
      updatedAt: Value(_now()),
    ),
  );

  /// Deletes term [id], keeping a tombstone so the delete syncs.
  Future<void> deleteTerm(String id) =>
      (_db.update(_db.glossaryTerms)..where((t) => t.id.equals(id))).write(
        GlossaryTermsCompanion(
          deletedAt: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );

  /// Terms of the active set that appear in [text], either side, as source term → preferred translation (AC-18.2).
  Future<Map<String, String>> termsIn(String text) async {
    final rows =
        await (_db.select(_db.glossaryTerms).join([
              innerJoin(
                _db.glossarySets,
                _db.glossarySets.id.equalsExp(_db.glossaryTerms.setId),
                useColumns: false,
              ),
            ])..where(
              _db.glossarySets.active.equals(true) &
                  _db.glossaryTerms.deletedAt.isNull(),
            ))
            .get();
    final haystack = text.toLowerCase();
    final found = <String, String>{};
    for (final row in rows) {
      final term = row.readTable(_db.glossaryTerms);
      if (_mentions(haystack, term.term)) {
        found[term.term] = term.translation;
      } else if (_mentions(haystack, term.translation)) {
        found[term.translation] = term.term;
      }
    }
    return found;
  }

  /// Whether [haystack] (lower case) contains [needle] as a whole word, or at all for scripts without spaces.
  static bool _mentions(String haystack, String needle) {
    final value = needle.trim().toLowerCase();
    if (value.isEmpty) {
      return false;
    }
    if (!RegExp(r'^[\p{L}\p{N}\s\-]+$', unicode: true).hasMatch(value) ||
        !RegExp(r'[a-z0-9]').hasMatch(value)) {
      return haystack.contains(value);
    }
    return RegExp(
      '(?<![\\p{L}\\p{N}])${RegExp.escape(value)}(?![\\p{L}\\p{N}])',
      unicode: true,
    ).hasMatch(haystack);
  }

  /// Returns null for a blank note.
  static String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}

/// Glossary sets with term counts.
final glossarySetsProvider =
    StreamProvider.autoDispose<List<GlossarySetSummary>>(
      (ref) => ref.watch(glossaryRepositoryProvider).watchSets(),
    );

/// One glossary set.
final glossarySetProvider = StreamProvider.autoDispose
    .family<GlossarySet?, String>(
      (ref, id) => ref.watch(glossaryRepositoryProvider).watchSet(id),
    );

/// Terms of one glossary set.
final glossaryTermsProvider = StreamProvider.autoDispose
    .family<List<GlossaryTerm>, String>(
      (ref, id) => ref.watch(glossaryRepositoryProvider).watchTerms(id),
    );

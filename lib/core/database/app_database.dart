import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// The app's local SQLite database.
@DriftDatabase(
  tables: [
    Sessions,
    Utterances,
    Phrases,
    Tags,
    PhraseTags,
    QuickPhraseFavorites,
    LanguagePacks,
    UsageLedger,
    SrsCards,
    GlossarySets,
    GlossaryTerms,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'lingo_mate'));

  @override
  int get schemaVersion => 5;

  /// Deletes every row of every table, children first (AC-10.3).
  Future<void> wipe() => transaction(() async {
    for (final table in allTables.toList().reversed) {
      await delete(table).go();
    }
  });

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createUtteranceSearch();
      await _createPhraseSearch();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _createUtteranceSearch();
        await customStatement(
          "INSERT INTO utterances_fts(utterances_fts) VALUES ('rebuild')",
        );
      }
      if (from < 3) {
        await _createPhraseSearch();
        await customStatement(
          "INSERT INTO phrases_fts(phrases_fts) VALUES ('rebuild')",
        );
      }
      if (from < 4) {
        await m.createTable(srsCards);
        await m.createIndex(srsCardsDue);
        await _addMissingCards();
      }
      if (from < 5) {
        if (!await _hasColumn('sessions', 'summary')) {
          await m.addColumn(sessions, sessions.summary);
        }
        for (final table in <TableInfo<Table, Object?>>[
          glossarySets,
          glossaryTerms,
        ]) {
          if (!await _hasTable(table.actualTableName)) {
            await m.createTable(table);
          }
        }
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Whether table [table] has column [column].
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((r) => r.read<String>('name') == column);
  }

  /// Whether table [table] exists.
  Future<bool> _hasTable(String table) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(table)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Adds forward and reverse cards, due now, for every phrase that has none (F-16).
  Future<void> _addMissingCards() async {
    for (final direction in ['forward', 'reverse']) {
      await customStatement(
        'INSERT INTO srs_cards (id, phrase_id, direction, due_at) '
        "SELECT p.id || '-' || ?, p.id, ?, p.created_at FROM phrases p "
        'WHERE NOT EXISTS (SELECT 1 FROM srs_cards c '
        'WHERE c.phrase_id = p.id AND c.direction = ?)',
        [direction, direction, direction],
      );
    }
  }

  /// Creates the FTS5 index over utterance texts and the triggers that keep it in sync (AC-07.3).
  Future<void> _createUtteranceSearch() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS utterances_fts USING fts5('
      'source_text, target_text, '
      "content='utterances', content_rowid='rowid', "
      "tokenize='unicode61 remove_diacritics 2')",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS utterances_fts_insert AFTER INSERT ON utterances BEGIN '
      'INSERT INTO utterances_fts(rowid, source_text, target_text) '
      'VALUES (new.rowid, new.source_text, new.target_text); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS utterances_fts_delete AFTER DELETE ON utterances BEGIN '
      'INSERT INTO utterances_fts(utterances_fts, rowid, source_text, target_text) '
      "VALUES ('delete', old.rowid, old.source_text, old.target_text); END",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS utterances_fts_update AFTER UPDATE ON utterances BEGIN '
      'INSERT INTO utterances_fts(utterances_fts, rowid, source_text, target_text) '
      "VALUES ('delete', old.rowid, old.source_text, old.target_text); "
      'INSERT INTO utterances_fts(rowid, source_text, target_text) '
      'VALUES (new.rowid, new.source_text, new.target_text); END',
    );
  }

  /// Creates the FTS5 index over phrase texts and notes and the triggers that keep it in sync (AC-08.4).
  Future<void> _createPhraseSearch() async {
    await customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS phrases_fts USING fts5('
      'source_text, target_text, note, '
      "content='phrases', content_rowid='rowid', "
      "tokenize='unicode61 remove_diacritics 2')",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS phrases_fts_insert AFTER INSERT ON phrases BEGIN '
      'INSERT INTO phrases_fts(rowid, source_text, target_text, note) '
      'VALUES (new.rowid, new.source_text, new.target_text, new.note); END',
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS phrases_fts_delete AFTER DELETE ON phrases BEGIN '
      'INSERT INTO phrases_fts(phrases_fts, rowid, source_text, target_text, note) '
      "VALUES ('delete', old.rowid, old.source_text, old.target_text, old.note); END",
    );
    await customStatement(
      'CREATE TRIGGER IF NOT EXISTS phrases_fts_update AFTER UPDATE ON phrases BEGIN '
      'INSERT INTO phrases_fts(phrases_fts, rowid, source_text, target_text, note) '
      "VALUES ('delete', old.rowid, old.source_text, old.target_text, old.note); "
      'INSERT INTO phrases_fts(rowid, source_text, target_text, note) '
      'VALUES (new.rowid, new.source_text, new.target_text, new.note); END',
    );
  }
}

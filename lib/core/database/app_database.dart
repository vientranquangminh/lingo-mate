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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'lingo_mate'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createUtteranceSearch();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await _createUtteranceSearch();
        await customStatement(
          "INSERT INTO utterances_fts(utterances_fts) VALUES ('rebuild')",
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
}

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

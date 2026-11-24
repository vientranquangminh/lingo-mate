import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Inserts a session with one utterance.
  Future<void> seedSession() async {
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            id: 's1',
            mode: 'conversation',
            engineInitial: 'offline',
            langA: 'vi',
            langB: 'en',
            startedAt: DateTime(2026, 11, 24),
          ),
        );
    await db
        .into(db.utterances)
        .insert(
          UtterancesCompanion.insert(
            id: 'u1',
            sessionId: 's1',
            sourceLang: 'vi',
            sourceText: 'Xin chào',
            targetLang: 'en',
            targetText: 'Hello',
            startMs: 0,
            endMs: 900,
            engine: 'offline',
          ),
        );
  }

  test('stores a session with its utterances', () async {
    await seedSession();

    final utterances = await db.select(db.utterances).get();

    expect(utterances.single.targetText, 'Hello');
    expect(utterances.single.isSaved, isFalse);
  });

  test('deleting a session deletes its utterances', () async {
    await seedSession();

    await (db.delete(db.sessions)..where((s) => s.id.equals('s1'))).go();

    expect(await db.select(db.utterances).get(), isEmpty);
  });

  test('rejects an utterance for a missing session', () async {
    expect(
      () => db
          .into(db.utterances)
          .insert(
            UtterancesCompanion.insert(
              id: 'u2',
              sessionId: 'missing',
              sourceLang: 'vi',
              sourceText: 'a',
              targetLang: 'en',
              targetText: 'a',
              startMs: 0,
              endMs: 1,
              engine: 'offline',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('usage ledger rows start unsynced', () async {
    await db
        .into(db.usageLedger)
        .insert(
          UsageLedgerCompanion.insert(
            engine: 'standard',
            seconds: 42,
            at: DateTime(2026, 11, 24),
          ),
        );

    final row = await db.select(db.usageLedger).getSingle();

    expect(row.synced, isFalse);
    expect(row.id, isA<int>());
    expect(row.seconds, 42);
  });
}

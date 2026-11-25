import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';

void main() {
  late AppDatabase db;
  late PhraseRepository repo;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 11, 25, 9);
    repo = PhraseRepository(
      db,
      now: () => now = now.add(const Duration(seconds: 1)),
    );
  });

  tearDown(() => db.close());

  /// Saves a vi → en phrase.
  Future<SaveResult> save(String source, String target, {String? utterance}) =>
      repo.save(
        sourceLang: 'vi',
        sourceText: source,
        targetLang: 'en',
        targetText: target,
        fromUtteranceId: utterance,
      );

  test(
    'a phrase saved from an utterance links to its session (AC-08.1)',
    () async {
      final sessions = SessionRepository(db);
      final sessionId = await sessions.start(
        mode: SessionMode.conversation,
        engine: EngineKind.standard,
        pair: const LanguagePair('vi', 'en'),
      );
      final utteranceId = await sessions.addUtterance(
        sessionId,
        const NewUtterance(
          speaker: 'a',
          sourceLang: 'vi',
          sourceText: 'Tính tiền giúp tôi',
          targetLang: 'en',
          targetText: 'Could we get the bill?',
          startMs: 60000,
          endMs: 62000,
          engine: UtteranceEngine.standard,
        ),
      );
      await sessions.finish(sessionId);
      await sessions.rename(sessionId, 'Lunch with Kenji');
      await save('Cảm ơn', 'Thank you');

      final result = await save(
        'Tính tiền giúp tôi',
        'Could we get the bill?',
        utterance: utteranceId,
      );

      expect(result.outcome, SaveOutcome.saved);
      final items = await repo.watch(const PhraseFilter()).first;
      expect(items.first.phrase.sourceText, 'Tính tiền giúp tôi');
      expect(items.first.sessionId, sessionId);
      expect(items.first.sessionTitle, 'Lunch with Kenji');
      expect(items.first.spokenAt, isNotNull);
      final utterance = (await sessions.load(sessionId))!.utterances.single;
      expect(utterance.isSaved, isTrue);
    },
  );

  test('the same source text and pair is not saved twice (AC-08.2)', () async {
    final first = await save('Cảm ơn', 'Thank you');
    final again = await save('  Cảm ơn ', 'Thanks');
    final otherPair = await repo.save(
      sourceLang: 'vi',
      sourceText: 'Cảm ơn',
      targetLang: 'ja',
      targetText: 'ありがとう',
    );

    expect(again, SaveResult(SaveOutcome.duplicate, first.id));
    expect(otherPair.outcome, SaveOutcome.saved);
    expect(await repo.watchCount().first, 2);
  });

  test(
    'filters by pair in either direction, tag, favourites and text',
    () async {
      final thanks = await save('Cảm ơn nhiều', 'Thank you so much');
      final bill = await save('Tính tiền giúp tôi', 'Could we get the bill?');
      await repo.save(
        sourceLang: 'en',
        sourceText: 'Good morning',
        targetLang: 'vi',
        targetText: 'Chào buổi sáng',
      );
      await repo.save(
        sourceLang: 'ja',
        sourceText: '一番近い駅はどこですか？',
        targetLang: 'en',
        targetText: "Where's the nearest train station?",
      );
      await repo.addTag(bill.id, 'Food');
      await repo.setFavorite(thanks.id, true);
      final food = (await repo.watchTags().first).single;

      Future<List<String>> sources(PhraseFilter f) async => [
        for (final i in await repo.watch(f).first) i.phrase.sourceText,
      ];

      expect(
        await sources(const PhraseFilter(pair: LanguagePair('en', 'vi'))),
        hasLength(3),
      );
      expect(await sources(PhraseFilter(tagId: food.id)), [
        'Tính tiền giúp tôi',
      ]);
      expect(await sources(const PhraseFilter(favoritesOnly: true)), [
        'Cảm ơn nhiều',
      ]);
      expect(await sources(const PhraseFilter(query: 'tinh tien')), [
        'Tính tiền giúp tôi',
      ]);
      expect(await sources(const PhraseFilter(query: "bill'; --")), [
        'Tính tiền giúp tôi',
      ]);
      expect(await repo.watchPairs().first, hasLength(2));
    },
  );

  test('lists update within 200 ms for 5,000 phrases (AC-08.4)', () async {
    await db.batch((b) {
      for (var i = 0; i < 5000; i++) {
        b.insert(
          db.phrases,
          PhrasesCompanion.insert(
            id: 'p$i',
            sourceLang: 'vi',
            sourceText: 'Câu số $i về thanh toán',
            targetLang: 'en',
            targetText: 'Sentence $i about payment',
            favorite: Value(i % 10 == 0),
            createdAt: DateTime(2026).add(Duration(minutes: i)),
            updatedAt: DateTime(2026),
          ),
        );
      }
    });

    final watch = Stopwatch()..start();
    final searched = await repo
        .watch(const PhraseFilter(query: 'payment', favoritesOnly: true))
        .first;
    watch.stop();

    expect(searched, hasLength(500));
    expect(watch.elapsedMilliseconds, lessThan(200));
  });

  test('tags are added once, removed, and unused tags dropped', () async {
    final p = await save('Cảm ơn', 'Thank you');

    await repo.addTag(p.id, 'Travel');
    await repo.addTag(p.id, 'Travel');
    await repo.addTag(p.id, ' Work ');
    var item = (await repo.watchOne(p.id).first)!;
    expect(item.tags.map((t) => t.name), ['Travel', 'Work']);

    await repo.removeTag(p.id, item.tags.first.id);
    item = (await repo.watchOne(p.id).first)!;
    expect(item.tags.map((t) => t.name), ['Work']);
    expect((await repo.watchTags().first).map((t) => t.name), ['Work']);
  });

  test('edit changes the translation and note', () async {
    final p = await save('Cảm ơn', 'Thank you');

    await repo.edit(p.id, targetText: 'Thanks a lot ', note: 'casual');

    final phrase = (await repo.watchOne(p.id).first)!.phrase;
    expect(phrase.targetText, 'Thanks a lot');
    expect(phrase.note, 'casual');
  });

  test('delete hides the phrase but keeps the row, and restore brings it back (AC-08.6)', () async {
    final p = await save('Cảm ơn', 'Thank you');

    await repo.softDelete(p.id);

    expect(await repo.watch(const PhraseFilter()).first, isEmpty);
    expect(await repo.watchOne(p.id).first, isNull);
    final row = await db.select(db.phrases).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(await repo.search(), isEmpty);

    await repo.restore(p.id);
    expect(await repo.watch(const PhraseFilter()).first, hasLength(1));
  });

  test('upgrading from schema 2 indexes existing phrases', () async {
    final dir = Directory.systemTemp.createTempSync('db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    final old = AppDatabase(NativeDatabase(file));
    await PhraseRepository(old).save(
      sourceLang: 'vi',
      sourceText: 'Cảm ơn',
      targetLang: 'en',
      targetText: 'Thank you',
    );
    for (final name in [
      'phrases_fts_insert',
      'phrases_fts_delete',
      'phrases_fts_update',
    ]) {
      await old.customStatement('DROP TRIGGER $name');
    }
    await old.customStatement('DROP TABLE phrases_fts');
    await old.customStatement('DROP TABLE srs_cards');
    await old.customStatement('PRAGMA user_version = 2');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    expect(
      await PhraseRepository(upgraded)
          .watch(const PhraseFilter(query: 'cam on'))
          .first,
      hasLength(1),
    );
  });

  test('a deleted phrase can be saved again', () async {
    final p = await save('Cảm ơn', 'Thank you');
    await repo.softDelete(p.id);

    final again = await save('Cảm ơn', 'Thank you');

    expect(again.outcome, SaveOutcome.saved);
  });
}

extension on PhraseRepository {
  /// Returns the phrases matching "cam on".
  Future<List<PhraseItem>> search() =>
      watch(const PhraseFilter(query: 'cam on')).first;
}

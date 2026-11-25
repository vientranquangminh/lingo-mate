import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/glossary/glossary_repository.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/review/review_repository.dart';
import 'package:lingo_mate/core/review/sm2.dart';
import 'package:lingo_mate/core/sync/cloud_store.dart';
import 'package:lingo_mate/core/sync/sync_engine.dart';

import 'sync_fakes.dart';

/// One phone: its database, clock and sync engine.
class _Device {
  _Device(this.store, {required DateTime start}) : now = start {
    db = AppDatabase(NativeDatabase.memory());
    engine = SyncEngine(
      db,
      store,
      'u1',
      lastPush: () => pushed,
      savePush: (ms) async => pushed = ms,
      now: () => now,
      debounce: const Duration(milliseconds: 10),
    );
  }

  final FakeCloudStore store;
  late final AppDatabase db;
  late final SyncEngine engine;
  DateTime now;
  int pushed = 0;

  PhraseRepository get phrases => PhraseRepository(db, now: () => now);
  ReviewRepository get review => ReviewRepository(db, now: () => now);
  GlossaryRepository get glossary => GlossaryRepository(db, now: () => now);

  /// Moves the clock forward by [seconds].
  void tick([int seconds = 5]) => now = now.add(Duration(seconds: seconds));

  /// Saves a vi → en phrase and returns its id.
  Future<String> save(String source, String target) async =>
      (await phrases.save(
        sourceLang: 'vi',
        sourceText: source,
        targetLang: 'en',
        targetText: target,
      )).id;

  /// Live phrases by source text.
  Future<Map<String, Phrase>> live() async => {
    for (final p in await (db.select(
      db.phrases,
    )..where((p) => p.deletedAt.isNull())).get())
      p.sourceText: p,
  };
}

/// Lets streams, debounce timers and pushes run.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

void main() {
  late FakeCloudStore store;
  late _Device a;
  late _Device b;

  setUp(() {
    store = FakeCloudStore();
    a = _Device(store, start: DateTime(2026, 11, 25, 9));
    b = _Device(store, start: DateTime(2026, 11, 25, 9));
  });

  tearDown(() async {
    await a.engine.stop();
    await b.engine.stop();
    await a.db.close();
    await b.db.close();
  });

  test('a phrase saved on one phone appears on the other with its cards and tags (AC-13.9)', () async {
    final id = await a.save('Cảm ơn', 'Thank you');
    await a.phrases.addTag(id, 'Travel');
    await a.engine.start();
    await b.engine.start();
    await settle();

    final onB = await b.live();
    expect(onB['Cảm ơn']!.targetText, 'Thank you');
    final tags = await b.phrases.watchOne(id).first;
    expect(tags!.tags.map((t) => t.name), ['Travel']);
    expect(await b.review.due(at: b.now), hasLength(2));
    expect(store.docs('u1', CloudCollection.phrases), hasLength(1));
  });

  test(
    'edits made while running sync both ways; the newest wins (AC-13.9)',
    () async {
      await a.engine.start();
      await b.engine.start();
      final id = await a.save('Cảm ơn', 'Thank you');
      await settle();

      b.tick(10);
      await b.phrases.edit(id, targetText: 'Thanks a lot');
      await settle();
      expect((await a.live())['Cảm ơn']!.targetText, 'Thanks a lot');

      a.tick(5);
      await a.phrases.edit(id, targetText: 'Old edit');
      await settle();
      expect((await b.live())['Cảm ơn']!.targetText, 'Thanks a lot');
    },
  );

  test('deletes travel as tombstones (AC-13.9)', () async {
    await a.engine.start();
    await b.engine.start();
    final id = await a.save('Cảm ơn', 'Thank you');
    await settle();
    expect(await b.live(), contains('Cảm ơn'));

    a.tick();
    await a.phrases.softDelete(id);
    await settle();

    expect(await b.live(), isEmpty);
    expect(
      store.docs('u1', CloudCollection.phrases).single.data['deletedAt'],
      isNotNull,
    );
  });

  test('review answers sync', () async {
    await a.engine.start();
    await b.engine.start();
    final id = await a.save('Cảm ơn', 'Thank you');
    await settle();

    b.tick();
    await b.review.answer(
      ReviewRepository.cardId(id, CardDirection.forward),
      ReviewGrade.good,
    );
    await settle();

    final card =
        await (a.db.select(a.db.srsCards)..where(
              (c) => c.id.equals(
                ReviewRepository.cardId(id, CardDirection.forward),
              ),
            ))
            .getSingle();
    expect(card.reps, 1);
  });

  test('merging keeps one copy of a phrase both sides had (AC-13.4)', () async {
    await a.save('Cảm ơn', 'Thank you');
    await a.engine.start();
    await settle();
    b.tick();
    await b.save('Cảm ơn', 'Thanks');
    await b.save('Xin chào', 'Hello');

    await b.engine.start();
    await settle();
    await settle();

    expect((await b.live()).keys.toSet(), {'Cảm ơn', 'Xin chào'});
    expect((await a.live()).keys.toSet(), {'Cảm ơn', 'Xin chào'});
  });

  test('glossaries sync, but the set in use stays per phone', () async {
    final setId = await a.glossary.createSet('Client A');
    await a.glossary.addTerm(setId, term: 'deploy', translation: 'triển khai');
    await a.glossary.setActive(setId, true);
    await a.engine.start();
    await b.engine.start();
    await settle();

    final sets = await b.glossary.watchSets().first;
    expect(sets.single.set.name, 'Client A');
    expect(sets.single.termCount, 1);
    expect(sets.single.set.active, isFalse);

    a.tick();
    await a.glossary.deleteSet(setId);
    await settle();
    expect(await b.glossary.watchSets().first, isEmpty);
  });

  test(
    'a card that arrives before its phrase is applied once the phrase lands',
    () async {
      final id = await a.save('Cảm ơn', 'Thank you');
      await a.engine.start();
      await settle();
      final phrases = store.docs('u1', CloudCollection.phrases);
      final empty = FakeCloudStore();
      await empty.putAll(
        'u1',
        CloudCollection.srs,
        store.docs('u1', CloudCollection.srs),
      );
      final c = _Device(empty, start: DateTime(2026, 11, 25, 9));
      addTearDown(() async {
        await c.engine.stop();
        await c.db.close();
      });
      await c.engine.start();
      await settle();
      expect(await c.db.select(c.db.srsCards).get(), isEmpty);

      await empty.putAll('u1', CloudCollection.phrases, phrases);
      await settle();

      final cards = await c.db.select(c.db.srsCards).get();
      expect(cards.map((x) => x.phraseId).toSet(), {id});
    },
  );
}

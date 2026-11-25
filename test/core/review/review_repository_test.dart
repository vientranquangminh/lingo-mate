import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/review/review_repository.dart';
import 'package:lingo_mate/core/review/sm2.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late PhraseRepository phrases;
  late ReviewRepository review;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 11, 25, 9);
    phrases = PhraseRepository(db, now: () => now);
    review = ReviewRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  /// Saves a vi → en phrase and returns its id.
  Future<String> save(String source, String target) async =>
      (await phrases.save(
        sourceLang: 'vi',
        sourceText: source,
        targetLang: 'en',
        targetText: target,
      )).id;

  test('saving a phrase adds a card each way, due now', () async {
    final id = await save('Cảm ơn', 'Thank you');

    final cards = await review.due();

    expect(cards, hasLength(2));
    final forward = cards.firstWhere(
      (c) => c.direction == CardDirection.forward,
    );
    final reverse = cards.firstWhere(
      (c) => c.direction == CardDirection.reverse,
    );
    expect(forward.prompt, 'Cảm ơn');
    expect(forward.answer, 'Thank you');
    expect(forward.answerLang, 'en');
    expect(reverse.prompt, 'Thank you');
    expect(reverse.promptLang, 'en');
    expect(forward.card.phraseId, id);
    expect(await review.watchDueCount().first, 2);
  });

  test('saving a duplicate adds no cards', () async {
    await save('Cảm ơn', 'Thank you');
    await save('Cảm ơn', 'Thanks');

    expect(await review.due(), hasLength(2));
  });

  test(
    'an answer stores the SM-2 state and the next due date (AC-16.1)',
    () async {
      final id = await save('Cảm ơn', 'Thank you');
      final cardId = ReviewRepository.cardId(id, CardDirection.forward);

      await review.answer(cardId, ReviewGrade.good);
      await review.answer(cardId, ReviewGrade.good);

      final card = await (db.select(
        db.srsCards,
      )..where((c) => c.id.equals(cardId))).getSingle();
      expect(card.reps, 2);
      expect(card.intervalDays, 6);
      expect(card.ease, 2.5);
      expect(card.dueAt, now.add(const Duration(days: 6)));
      expect(card.lastReviewedAt, now);
      expect(await review.due(), hasLength(1));
      expect(
        await review.due(at: now.add(const Duration(days: 6))),
        hasLength(2),
      );
    },
  );

  test('cards of a deleted phrase are not due', () async {
    final id = await save('Cảm ơn', 'Thank you');

    await phrases.softDelete(id);

    expect(await review.due(), isEmpty);
    expect(await review.watchDueCount().first, 0);
    expect(await review.nextDue(), isNull);
  });

  test('nextDue is the earliest due card', () async {
    final id = await save('Cảm ơn', 'Thank you');
    for (final direction in CardDirection.values) {
      await review.answer(
        ReviewRepository.cardId(id, direction),
        direction == CardDirection.forward
            ? ReviewGrade.good
            : ReviewGrade.easy,
      );
    }

    expect(await review.nextDue(), now.add(const Duration(days: 1)));
  });

  test('upgrading from schema 3 adds cards for existing phrases', () async {
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
    await old.customStatement('DROP TABLE srs_cards');
    await old.customStatement('PRAGMA user_version = 3');
    await old.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    final cards = await ReviewRepository(upgraded).due();
    expect(cards.map((c) => c.direction).toSet(), CardDirection.values.toSet());
  });
}

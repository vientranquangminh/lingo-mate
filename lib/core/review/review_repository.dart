import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../sessions/session_repository.dart';
import 'sm2.dart';

/// Which side of a phrase a card asks for.
enum CardDirection {
  forward,
  reverse;

  /// The direction stored under [name], forward when unknown.
  static CardDirection parse(String name) =>
      values.where((d) => d.name == name).firstOrNull ?? forward;
}

/// A due card with the phrase it asks about.
class ReviewCard extends Equatable {
  const ReviewCard({required this.card, required this.phrase});

  final SrsCard card;
  final Phrase phrase;

  CardDirection get direction => CardDirection.parse(card.direction);

  /// The side shown before the answer is revealed.
  String get prompt => direction == CardDirection.forward
      ? phrase.sourceText
      : phrase.targetText;

  /// Language of [prompt].
  String get promptLang => direction == CardDirection.forward
      ? phrase.sourceLang
      : phrase.targetLang;

  /// The side revealed as the answer.
  String get answer => direction == CardDirection.forward
      ? phrase.targetText
      : phrase.sourceText;

  /// Language of [answer].
  String get answerLang => direction == CardDirection.forward
      ? phrase.targetLang
      : phrase.sourceLang;

  Sm2State get state => Sm2State(
    ease: card.ease,
    intervalDays: card.intervalDays,
    reps: card.reps,
    lapses: card.lapses,
  );

  @override
  List<Object?> get props => [card, phrase];
}

/// Review cards.
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(ref.watch(appDatabaseProvider)),
);

/// Spaced-repetition cards over the phrasebook, scheduled with SM-2 and kept offline (F-16).
class ReviewRepository {
  ReviewRepository(
    this._db, {
    DateTime Function()? now,
    this._scheduler = const Sm2Scheduler(),
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;
  final Sm2Scheduler _scheduler;

  /// Id of the card for [direction] of phrase [phraseId].
  static String cardId(String phraseId, CardDirection direction) =>
      '$phraseId-${direction.name}';

  /// Adds the forward and reverse cards of phrase [phraseId], due now, unless they exist.
  Future<void> addCards(String phraseId) async {
    final now = _now();
    for (final direction in CardDirection.values) {
      await _db
          .into(_db.srsCards)
          .insert(
            SrsCardsCompanion.insert(
              id: cardId(phraseId, direction),
              phraseId: phraseId,
              direction: direction.name,
              dueAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  /// Joins cards with phrases that are not deleted.
  JoinedSelectStatement<HasResultSet, dynamic> _joined() =>
      _db.select(_db.srsCards).join([
        innerJoin(_db.phrases, _db.phrases.id.equalsExp(_db.srsCards.phraseId)),
      ]);

  /// Cards due at [at] (now by default), oldest due first.
  Future<List<ReviewCard>> due({DateTime? at}) async {
    final query = _joined()
      ..where(
        _db.phrases.deletedAt.isNull() &
            _db.srsCards.dueAt.isSmallerOrEqualValue(at ?? _now()),
      )
      ..orderBy([
        OrderingTerm.asc(_db.srsCards.dueAt),
        OrderingTerm.asc(_db.srsCards.id),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        ReviewCard(
          card: row.readTable(_db.srsCards),
          phrase: row.readTable(_db.phrases),
        ),
    ];
  }

  /// Number of cards due now, updated as cards and phrases change.
  Stream<int> watchDueCount() {
    final count = _db.srsCards.id.count();
    final query =
        _db.selectOnly(_db.srsCards).join([
            innerJoin(
              _db.phrases,
              _db.phrases.id.equalsExp(_db.srsCards.phraseId),
              useColumns: false,
            ),
          ])
          ..addColumns([count])
          ..where(
            _db.phrases.deletedAt.isNull() &
                _db.srsCards.dueAt.isSmallerOrEqualValue(_now()),
          );
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  /// When the next card falls due, or null with no cards.
  Future<DateTime?> nextDue() async {
    final first = _db.srsCards.dueAt.min();
    final query =
        _db.selectOnly(_db.srsCards).join([
            innerJoin(
              _db.phrases,
              _db.phrases.id.equalsExp(_db.srsCards.phraseId),
              useColumns: false,
            ),
          ])
          ..addColumns([first])
          ..where(_db.phrases.deletedAt.isNull());
    return (await query.getSingle()).read(first);
  }

  /// Records [grade] for card [id] and schedules its next review (AC-16.1).
  Future<Sm2State> answer(String id, ReviewGrade grade) async {
    final card = await (_db.select(
      _db.srsCards,
    )..where((c) => c.id.equals(id))).getSingle();
    final next = _scheduler.answer(
      Sm2State(
        ease: card.ease,
        intervalDays: card.intervalDays,
        reps: card.reps,
        lapses: card.lapses,
      ),
      grade,
    );
    final now = _now();
    await (_db.update(_db.srsCards)..where((c) => c.id.equals(id))).write(
      SrsCardsCompanion(
        ease: Value(next.ease),
        intervalDays: Value(next.intervalDays),
        reps: Value(next.reps),
        lapses: Value(next.lapses),
        dueAt: Value(now.add(Duration(days: next.intervalDays))),
        lastReviewedAt: Value(now),
      ),
    );
    return next;
  }
}

/// Number of review cards due now (S-11 banner).
final reviewDueCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(reviewRepositoryProvider).watchDueCount(),
);

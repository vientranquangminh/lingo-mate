import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/review/sm2.dart';

void main() {
  const scheduler = Sm2Scheduler();

  test('Good three times gives 1, 6 and 15 days at ease 2.5 (AC-16.1)', () {
    var state = const Sm2State();
    final intervals = <int>[];
    for (var i = 0; i < 3; i++) {
      state = scheduler.answer(state, ReviewGrade.good);
      intervals.add(state.intervalDays);
    }

    expect(intervals, [1, 6, 15]);
    expect(state.ease, 2.5);
    expect(state.reps, 3);
    expect(state.lapses, 0);
  });

  test('each grade moves ease by the SM-2 formula (AC-16.1)', () {
    expect(scheduler.answer(const Sm2State(), ReviewGrade.easy).ease, 2.6);
    expect(scheduler.answer(const Sm2State(), ReviewGrade.good).ease, 2.5);
    expect(scheduler.answer(const Sm2State(), ReviewGrade.hard).ease, 2.36);
    expect(scheduler.answer(const Sm2State(), ReviewGrade.again).ease, 1.96);
  });

  test('the interval uses the ease before the answer (AC-16.1)', () {
    final next = scheduler.answer(
      const Sm2State(ease: 2.6, intervalDays: 15, reps: 3),
      ReviewGrade.easy,
    );

    expect(next.intervalDays, 39);
    expect(next.ease, 2.7);
    expect(next.reps, 4);
  });

  test('Again resets repetitions, counts a lapse and comes back tomorrow', () {
    final next = scheduler.answer(
      const Sm2State(ease: 2.5, intervalDays: 15, reps: 3, lapses: 1),
      ReviewGrade.again,
    );

    expect(
      next,
      const Sm2State(ease: 1.96, intervalDays: 1, reps: 0, lapses: 2),
    );
  });

  test('ease never drops below 1.3', () {
    final next = scheduler.answer(const Sm2State(ease: 1.4), ReviewGrade.again);

    expect(next.ease, Sm2Scheduler.minEase);
  });

  test('Hard keeps the card in the session, Good and Easy let it go', () {
    expect(ReviewGrade.again.needsDrill, isTrue);
    expect(ReviewGrade.hard.needsDrill, isTrue);
    expect(ReviewGrade.good.needsDrill, isFalse);
    expect(ReviewGrade.easy.needsDrill, isFalse);
  });
}

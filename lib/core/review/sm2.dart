import 'dart:math';

import 'package:equatable/equatable.dart';

/// How well the user remembered a card.
enum ReviewGrade {
  again(1),
  hard(3),
  good(4),
  easy(5);

  const ReviewGrade(this.quality);

  final int quality;

  /// Whether SM-2 asks to see the card again in the same session.
  bool get needsDrill => quality < 4;
}

/// The SM-2 state of one card.
class Sm2State extends Equatable {
  const Sm2State({
    this.ease = Sm2Scheduler.initialEase,
    this.intervalDays = 0,
    this.reps = 0,
    this.lapses = 0,
  });

  final double ease;
  final int intervalDays;
  final int reps;
  final int lapses;

  @override
  List<Object?> get props => [ease, intervalDays, reps, lapses];
}

/// SuperMemo 2 scheduling with the grades mapped to qualities 1, 3, 4 and 5 (AC-16.1).
class Sm2Scheduler {
  const Sm2Scheduler();

  static const initialEase = 2.5;
  static const minEase = 1.3;

  /// Returns the state after answering [grade] on a card in [state].
  Sm2State answer(Sm2State state, ReviewGrade grade) {
    final q = grade.quality;
    final ease = max(
      minEase,
      _round(state.ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))),
    );
    if (q < 3) {
      return Sm2State(
        ease: ease,
        intervalDays: 1,
        reps: 0,
        lapses: state.lapses + 1,
      );
    }
    final interval = switch (state.reps) {
      0 => 1,
      1 => 6,
      _ => (state.intervalDays * state.ease).round(),
    };
    return Sm2State(
      ease: ease,
      intervalDays: interval,
      reps: state.reps + 1,
      lapses: state.lapses,
    );
  }

  /// Rounds [value] to two decimals so repeated updates don't drift.
  static double _round(double value) => (value * 100).round() / 100;
}

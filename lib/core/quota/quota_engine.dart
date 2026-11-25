import 'dart:math';

import 'package:equatable/equatable.dart';

/// The Standard allowance of a plan: a 5-hour window and a weekly window (doc 03 §10).
class QuotaLimits extends Equatable {
  const QuotaLimits({required this.win5hSec, required this.weekSec});

  /// Reads the limits of [plan] and [engine] from Remote Config `quota_limits`, falling back to [fallback].
  factory QuotaLimits.from(
    Map<String, dynamic> json, {
    String plan = 'free',
    String engine = 'standard',
    QuotaLimits fallback = const QuotaLimits(win5hSec: 1800, weekSec: 3600),
  }) {
    final entry = (json[plan] as Map?)?[engine] as Map?;
    final win = entry?['win5hSec'];
    final week = entry?['weekSec'];
    return QuotaLimits(
      win5hSec: win is num ? win.toInt() : fallback.win5hSec,
      weekSec: week is num ? week.toInt() : fallback.weekSec,
    );
  }

  final int win5hSec;
  final int weekSec;

  @override
  List<Object?> get props => [win5hSec, weekSec];
}

/// One rolling window: when it started, how much is used and when it resets; [start] is null with no active window.
class QuotaWindow extends Equatable {
  const QuotaWindow({
    required this.limitSec,
    this.start,
    this.usedSec = 0,
    this.resetAt,
  });

  final int limitSec;
  final DateTime? start;
  final int usedSec;
  final DateTime? resetAt;

  int get remainingSec => max(0, limitSec - usedSec);

  /// Share of the window used, 0 to 1.
  double get fraction =>
      limitSec <= 0 ? 1 : min(1, usedSec / limitSec).toDouble();

  @override
  List<Object?> get props => [limitSec, start, usedSec, resetAt];
}

/// Where a user stands against both windows.
class QuotaStatus extends Equatable {
  const QuotaStatus({required this.window, required this.week});

  final QuotaWindow window;
  final QuotaWindow week;

  /// Seconds left before either window runs out.
  int get remainingSec => min(window.remainingSec, week.remainingSec);

  bool get exhausted => remainingSec <= 0;

  /// The larger share used of the two windows.
  double get fraction => max(window.fraction, week.fraction);

  /// When use is allowed again: the earliest reset among the exhausted windows.
  DateTime? get resetAt {
    final resets = [
      if (window.remainingSec <= 0) window.resetAt,
      if (week.remainingSec <= 0) week.resetAt,
    ].whereType<DateTime>().toList()..sort();
    return resets.firstOrNull;
  }

  @override
  List<Object?> get props => [window, week];
}

/// One metered use: when and how many seconds.
typedef MeteredUse = ({DateTime at, int seconds});

/// Windows that start at the first use after the previous one expired (AC-14.1).
abstract final class QuotaEngine {
  static const windowLength = Duration(hours: 5);
  static const weekLength = Duration(days: 7);

  /// Returns the status at [now] for [uses] under [limits].
  static QuotaStatus compute(
    Iterable<MeteredUse> uses,
    QuotaLimits limits, {
    required DateTime now,
  }) {
    final sorted = uses.toList()..sort((a, b) => a.at.compareTo(b.at));
    return QuotaStatus(
      window: _window(sorted, windowLength, limits.win5hSec, now),
      week: _window(sorted, weekLength, limits.weekSec, now),
    );
  }

  /// Walks [uses] and returns the window of [length] that is active at [now].
  static QuotaWindow _window(
    List<MeteredUse> uses,
    Duration length,
    int limit,
    DateTime now,
  ) {
    DateTime? start;
    var used = 0;
    for (final use in uses) {
      if (start == null || !use.at.isBefore(start.add(length))) {
        start = use.at;
        used = 0;
      }
      used += use.seconds;
    }
    if (start == null || !now.isBefore(start.add(length))) {
      return QuotaWindow(limitSec: limit);
    }
    return QuotaWindow(
      limitSec: limit,
      start: start,
      usedSec: used,
      resetAt: start.add(length),
    );
  }
}

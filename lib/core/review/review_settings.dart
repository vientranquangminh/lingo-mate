import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/user_settings.dart';

/// The review streak and the daily reminder choice (F-16).
class ReviewSettings extends Equatable {
  const ReviewSettings({
    this.streak = 0,
    this.lastReviewDay,
    this.reminderOn = false,
    this.reminderMinutes = defaultReminderMinutes,
  });

  static const defaultReminderMinutes = 20 * 60;

  final int streak;
  final DateTime? lastReviewDay;
  final bool reminderOn;
  final int reminderMinutes;

  /// Days in a row with a review, counting today or yesterday as still running.
  int streakOn(DateTime now) {
    final last = lastReviewDay;
    if (last == null) {
      return 0;
    }
    final gap = dayOf(now).difference(last).inDays;
    return gap <= 1 ? streak : 0;
  }

  /// Midnight at the start of [time]'s day.
  static DateTime dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  /// Returns a copy with the given fields replaced.
  ReviewSettings copyWith({
    int? streak,
    DateTime? lastReviewDay,
    bool? reminderOn,
    int? reminderMinutes,
  }) => ReviewSettings(
    streak: streak ?? this.streak,
    lastReviewDay: lastReviewDay ?? this.lastReviewDay,
    reminderOn: reminderOn ?? this.reminderOn,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
  );

  @override
  List<Object?> get props => [
    streak,
    lastReviewDay,
    reminderOn,
    reminderMinutes,
  ];
}

/// The review streak and reminder choice.
final reviewSettingsProvider =
    NotifierProvider<ReviewSettingsNotifier, ReviewSettings>(
      ReviewSettingsNotifier.new,
    );

/// Loads and saves [ReviewSettings] in shared preferences.
class ReviewSettingsNotifier extends Notifier<ReviewSettings> {
  static const _streak = 'review_streak';
  static const _lastDay = 'review_last_day';
  static const _reminderOn = 'review_reminder_on';
  static const _reminderMinutes = 'review_reminder_minutes';

  @override
  ReviewSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final last = prefs.getString(_lastDay);
    return ReviewSettings(
      streak: prefs.getInt(_streak) ?? 0,
      lastReviewDay: last == null ? null : DateTime.tryParse(last),
      reminderOn: prefs.getBool(_reminderOn) ?? false,
      reminderMinutes:
          prefs.getInt(_reminderMinutes) ??
          ReviewSettings.defaultReminderMinutes,
    );
  }

  /// Counts a review done at [now] towards the streak.
  Future<void> recordReview(DateTime now) async {
    final today = ReviewSettings.dayOf(now);
    final last = state.lastReviewDay;
    if (last == today) {
      return;
    }
    final streak = state.streakOn(now) + 1;
    state = state.copyWith(streak: streak, lastReviewDay: today);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_streak, streak);
    await prefs.setString(_lastDay, today.toIso8601String());
  }

  /// Turns the daily reminder on or off.
  Future<void> setReminderOn(bool on) async {
    state = state.copyWith(reminderOn: on);
    await ref.read(sharedPreferencesProvider).setBool(_reminderOn, on);
  }

  /// Sets the reminder time as minutes after midnight.
  Future<void> setReminderMinutes(int minutes) async {
    state = state.copyWith(reminderMinutes: minutes);
    await ref.read(sharedPreferencesProvider).setInt(_reminderMinutes, minutes);
  }
}

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/review/review_reminder.dart';
import 'package:lingo_mate/core/review/review_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'review_fakes.dart';

void main() {
  group('nextReminderTime', () {
    test('today when the time is still ahead and cards are due', () {
      expect(
        nextReminderTime(
          now: DateTime(2026, 11, 25, 9),
          due: DateTime(2026, 11, 24, 12),
          minutes: 20 * 60,
        ),
        DateTime(2026, 11, 25, 20),
      );
    });

    test('tomorrow when today\'s time has passed', () {
      expect(
        nextReminderTime(
          now: DateTime(2026, 11, 25, 21),
          due: DateTime(2026, 11, 25, 8),
          minutes: 20 * 60,
        ),
        DateTime(2026, 11, 26, 20),
      );
    });

    test('on the first day with cards due (AC-16.3)', () {
      expect(
        nextReminderTime(
          now: DateTime(2026, 11, 25, 9),
          due: DateTime(2026, 11, 28, 21),
          minutes: 20 * 60 + 30,
        ),
        DateTime(2026, 11, 29, 20, 30),
      );
    });
  });

  group('ReviewSettings', () {
    test('the streak runs through yesterday and resets after a gap', () {
      final settings = ReviewSettings(
        streak: 4,
        lastReviewDay: DateTime(2026, 11, 24),
      );

      expect(settings.streakOn(DateTime(2026, 11, 24, 23)), 4);
      expect(settings.streakOn(DateTime(2026, 11, 25, 7)), 4);
      expect(settings.streakOn(DateTime(2026, 11, 26, 7)), 0);
    });

    test('recordReview adds a day once per day', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(reviewSettingsProvider.notifier);

      await notifier.recordReview(DateTime(2026, 11, 24, 9));
      await notifier.recordReview(DateTime(2026, 11, 24, 21));
      await notifier.recordReview(DateTime(2026, 11, 25, 9));

      expect(container.read(reviewSettingsProvider).streak, 2);
      await notifier.recordReview(DateTime(2026, 11, 27, 9));
      expect(container.read(reviewSettingsProvider).streak, 1);
    });
  });

  group('reminder sync', () {
    late AppDatabase db;
    late FakeReminderScheduler scheduler;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'app_locale': 'vi'});
      db = AppDatabase(NativeDatabase.memory());
      scheduler = FakeReminderScheduler();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          appDatabaseProvider.overrideWithValue(db),
          reviewReminderSchedulerProvider.overrideWithValue(scheduler),
          reviewClockProvider.overrideWithValue(
            () => DateTime(2026, 11, 25, 9),
          ),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('nothing is scheduled while the reminder is off', () async {
      await PhraseRepository(db).save(
        sourceLang: 'vi',
        sourceText: 'Cảm ơn',
        targetLang: 'en',
        targetText: 'Thank you',
      );

      await container.read(reviewReminderSyncProvider)();

      expect(scheduler.scheduled, isNull);
      expect(scheduler.cancels, 1);
    });

    test(
      'with cards due the reminder is set for the chosen time (AC-16.3)',
      () async {
        await PhraseRepository(db, now: () => DateTime(2026, 11, 25, 8)).save(
          sourceLang: 'vi',
          sourceText: 'Cảm ơn',
          targetLang: 'en',
          targetText: 'Thank you',
        );
        final settings = container.read(reviewSettingsProvider.notifier);
        await settings.setReminderOn(true);
        await settings.setReminderMinutes(19 * 60 + 15);

        await container.read(reviewReminderSyncProvider)();

        expect(scheduler.scheduled, DateTime(2026, 11, 25, 19, 15));
        expect(scheduler.title, 'Đến giờ ôn tập');
      },
    );

    test('with no cards the reminder is removed', () async {
      await container.read(reviewSettingsProvider.notifier).setReminderOn(true);

      await container.read(reviewReminderSyncProvider)();

      expect(scheduler.scheduled, isNull);
      expect(scheduler.cancels, 1);
    });
  });
}

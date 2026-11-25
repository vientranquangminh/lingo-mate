import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/l10n.dart';
import '../settings/user_settings.dart';
import 'review_repository.dart';
import 'review_settings.dart';

/// Schedules the daily review notification (`ReviewReminderChannel.kt`).
abstract interface class ReviewReminderScheduler {
  /// Shows [title] and [body] at [first], then every day at the same time.
  Future<void> schedule(
    DateTime first, {
    required String title,
    required String body,
  });

  /// Removes the scheduled reminder.
  Future<void> cancel();
}

/// [ReviewReminderScheduler] over the `lingomate/review_reminder` channel.
class ChannelReviewReminderScheduler implements ReviewReminderScheduler {
  const ChannelReviewReminderScheduler();

  static const _channel = MethodChannel('lingomate/review_reminder');

  @override
  Future<void> schedule(
    DateTime first, {
    required String title,
    required String body,
  }) => _invoke('schedule', {
    'atMillis': first.millisecondsSinceEpoch,
    'title': title,
    'body': body,
  });

  @override
  Future<void> cancel() => _invoke('cancel');

  /// Calls [method], ignoring platforms without the channel.
  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

/// The platform reminder scheduler.
final reviewReminderSchedulerProvider = Provider<ReviewReminderScheduler>(
  (ref) => const ChannelReviewReminderScheduler(),
);

/// Clock used for reminder scheduling.
final reviewClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The first reminder time at [minutes] after midnight that is at or after both [now] and [due] (AC-16.3).
DateTime nextReminderTime({
  required DateTime now,
  required DateTime due,
  required int minutes,
}) {
  final from = due.isAfter(now) ? due : now;
  var at = DateTime(
    from.year,
    from.month,
    from.day,
    minutes ~/ 60,
    minutes % 60,
  );
  if (at.isBefore(from)) {
    at = DateTime(at.year, at.month, at.day + 1, minutes ~/ 60, minutes % 60);
  }
  return at;
}

/// Keeps the scheduled reminder in line with the setting and the next due card.
final reviewReminderSyncProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final settings = ref.read(reviewSettingsProvider);
    final scheduler = ref.read(reviewReminderSchedulerProvider);
    final due = settings.reminderOn
        ? await ref.read(reviewRepositoryProvider).nextDue()
        : null;
    if (due == null) {
      await scheduler.cancel();
      return;
    }
    final l10n = lookupAppLocalizations(_locale(ref));
    await scheduler.schedule(
      nextReminderTime(
        now: ref.read(reviewClockProvider)(),
        due: due,
        minutes: settings.reminderMinutes,
      ),
      title: l10n.reviewReminderTitle,
      body: l10n.reviewReminderBody,
    );
  },
);

/// The app language, else the phone's when supported, else English.
Locale _locale(Ref ref) {
  final chosen = ref.read(userSettingsProvider).appLocale;
  final code = chosen ?? PlatformDispatcher.instance.locale.languageCode;
  return AppLocalizations.supportedLocales.firstWhere(
    (l) => l.languageCode == code,
    orElse: () => const Locale('en'),
  );
}

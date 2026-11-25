import 'package:lingo_mate/core/review/review_reminder.dart';

/// Records what the app asks the platform to schedule.
class FakeReminderScheduler implements ReviewReminderScheduler {
  DateTime? scheduled;
  String? title;
  int cancels = 0;

  @override
  Future<void> schedule(
    DateTime first, {
    required String title,
    required String body,
  }) async {
    scheduled = first;
    this.title = title;
  }

  @override
  Future<void> cancel() async {
    scheduled = null;
    cancels++;
  }
}

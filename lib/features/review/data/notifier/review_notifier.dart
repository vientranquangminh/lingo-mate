import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/review/review_reminder.dart';
import '../../../../core/review/review_repository.dart';
import '../../../../core/review/review_settings.dart';
import '../../../../core/review/sm2.dart';
import '../state/review_state.dart';

/// The open review session.
final reviewProvider =
    NotifierProvider.autoDispose<ReviewNotifier, ReviewState>(
      ReviewNotifier.new,
    );

/// Runs a review session over the due cards; cards graded below Good come back at the end until graded Good or Easy, as SM-2 asks (AC-16.1).
class ReviewNotifier extends Notifier<ReviewState> {
  @override
  ReviewState build() {
    _load();
    return const ReviewState();
  }

  /// Loads the cards due now.
  Future<void> _load() async {
    final cards = await ref.read(reviewRepositoryProvider).due();
    if (!ref.mounted) {
      return;
    }
    state = ReviewState(
      status: cards.isEmpty ? ReviewStatus.done : ReviewStatus.active,
      queue: cards,
      total: cards.length,
    );
  }

  /// Shows the answer of the current card.
  void reveal() {
    if (state.current != null) {
      state = state.copyWith(revealed: true);
    }
  }

  /// Grades the current card; only the first answer of a session changes its schedule.
  Future<void> grade(ReviewGrade grade) async {
    final card = state.current;
    if (card == null || !state.revealed) {
      return;
    }
    final id = card.card.id;
    final drilled = state.drills.contains(id);
    final rest = state.queue.skip(1).toList();
    final drills = {...state.drills};
    var finished = state.finished;
    if (grade.needsDrill) {
      rest.add(card);
      drills.add(id);
    } else {
      drills.remove(id);
      finished++;
    }
    state = state.copyWith(
      queue: rest,
      drills: drills,
      revealed: false,
      finished: finished,
      status: rest.isEmpty ? ReviewStatus.done : ReviewStatus.active,
    );
    final repository = ref.read(reviewRepositoryProvider);
    final settings = ref.read(reviewSettingsProvider.notifier);
    final now = ref.read(reviewClockProvider)();
    final sync = ref.read(reviewReminderSyncProvider);
    if (!drilled) {
      await repository.answer(id, grade);
      await settings.recordReview(now);
    }
    if (rest.isEmpty) {
      await sync();
    }
  }
}

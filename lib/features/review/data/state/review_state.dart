import 'package:equatable/equatable.dart';

import '../../../../core/review/review_repository.dart';

/// Where a review session stands.
enum ReviewStatus { loading, active, done }

/// A review session: the cards left, whether the answer shows and progress (S-20).
class ReviewState extends Equatable {
  const ReviewState({
    this.status = ReviewStatus.loading,
    this.queue = const [],
    this.drills = const {},
    this.revealed = false,
    this.total = 0,
    this.finished = 0,
  });

  final ReviewStatus status;
  final List<ReviewCard> queue;
  final Set<String> drills;
  final bool revealed;
  final int total;
  final int finished;

  ReviewCard? get current => queue.firstOrNull;

  /// Returns a copy with the given fields replaced.
  ReviewState copyWith({
    ReviewStatus? status,
    List<ReviewCard>? queue,
    Set<String>? drills,
    bool? revealed,
    int? total,
    int? finished,
  }) => ReviewState(
    status: status ?? this.status,
    queue: queue ?? this.queue,
    drills: drills ?? this.drills,
    revealed: revealed ?? this.revealed,
    total: total ?? this.total,
    finished: finished ?? this.finished,
  );

  @override
  List<Object?> get props => [status, queue, drills, revealed, total, finished];
}

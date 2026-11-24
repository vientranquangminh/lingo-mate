import 'package:equatable/equatable.dart';

/// Background soak test (T-0.8): how long capture ran and whether audio ever stopped arriving.
class SoakState extends Equatable {
  const SoakState({
    this.running = false,
    this.elapsed = Duration.zero,
    this.segments = 0,
    this.maxGapMs = 0,
    this.overlayShown = false,
    this.overlayDenied = false,
    this.savedLines = const [],
    this.error = '',
  });

  final bool running;
  final Duration elapsed;
  final int segments;
  final int maxGapMs;
  final bool overlayShown;
  final bool overlayDenied;
  final List<String> savedLines;
  final String error;

  SoakState copyWith({
    bool? running,
    Duration? elapsed,
    int? segments,
    int? maxGapMs,
    bool? overlayShown,
    bool? overlayDenied,
    List<String>? savedLines,
    String? error,
  }) {
    return SoakState(
      running: running ?? this.running,
      elapsed: elapsed ?? this.elapsed,
      segments: segments ?? this.segments,
      maxGapMs: maxGapMs ?? this.maxGapMs,
      overlayShown: overlayShown ?? this.overlayShown,
      overlayDenied: overlayDenied ?? this.overlayDenied,
      savedLines: savedLines ?? this.savedLines,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    running,
    elapsed,
    segments,
    maxGapMs,
    overlayShown,
    overlayDenied,
    savedLines,
    error,
  ];
}

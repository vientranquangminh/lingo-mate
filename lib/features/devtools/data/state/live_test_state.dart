import 'package:equatable/equatable.dart';

/// One line of a Live test transcript.
class LiveLine extends Equatable {
  const LiveLine({
    required this.target,
    required this.input,
    required this.output,
  });

  final String target;
  final String input;
  final String output;

  @override
  List<Object?> get props => [target, input, output];
}

/// State of the devtools Live test (T-0.5 spike).
class LiveTestState extends Equatable {
  const LiveTestState({
    this.running = false,
    this.twoWay = false,
    this.lines = const [],
    this.lagsMs = const [],
    this.error = '',
  });

  final bool running;
  final bool twoWay;
  final List<LiveLine> lines;
  final List<int> lagsMs;
  final String error;

  /// Median lag from the first input transcript of a turn to its first translated audio.
  int? get medianLagMs {
    if (lagsMs.isEmpty) {
      return null;
    }
    final sorted = [...lagsMs]..sort();
    return sorted[sorted.length ~/ 2];
  }

  LiveTestState copyWith({
    bool? running,
    bool? twoWay,
    List<LiveLine>? lines,
    List<int>? lagsMs,
    String? error,
  }) {
    return LiveTestState(
      running: running ?? this.running,
      twoWay: twoWay ?? this.twoWay,
      lines: lines ?? this.lines,
      lagsMs: lagsMs ?? this.lagsMs,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [running, twoWay, lines, lagsMs, error];
}

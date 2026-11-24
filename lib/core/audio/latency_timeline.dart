/// Latency stages of one utterance (doc 07 §5).
enum LatencyStage { vadEnd, asrDone, translationShown, playbackStart }

/// Records when each stage of an utterance happened.
class LatencyTimeline {
  LatencyTimeline({required this._nowMs});

  final int Function() _nowMs;
  final _marks = <LatencyStage, int>{};

  /// Records the current time for a stage, keeping the first mark.
  void mark(LatencyStage stage) => _marks.putIfAbsent(stage, _nowMs);

  /// Returns the time recorded for a stage, if any.
  int? at(LatencyStage stage) => _marks[stage];

  /// Returns the milliseconds from VAD end to a stage, if both were recorded.
  int? sinceVadEnd(LatencyStage stage) {
    final start = _marks[LatencyStage.vadEnd];
    final end = _marks[stage];
    return start == null || end == null ? null : end - start;
  }

  /// Returns the stage times relative to VAD end, for the latency HUD and CSV export.
  Map<String, int?> toRow() => {
    for (final stage in LatencyStage.values) stage.name: sinceVadEnd(stage),
  };
}

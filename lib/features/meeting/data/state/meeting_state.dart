import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../model/meeting_models.dart';

/// Meeting state: languages, engine, whether capture runs, overlay status and the transcript.
class MeetingState extends Equatable {
  const MeetingState({
    this.source = 'en',
    this.target = 'vi',
    this.engine,
    this.blocked = const {},
    this.running = false,
    this.starting = false,
    this.overlayShown = false,
    this.inAppOnly = false,
    this.lines = const [],
    this.block,
    this.savedCount = 0,
  });

  final String source;
  final String target;
  final EngineKind? engine;
  final Map<EngineKind, EngineBlock> blocked;
  final bool running;
  final bool starting;
  final bool overlayShown;
  final bool inAppOnly;
  final List<MeetingLine> lines;
  final MeetingBlock? block;
  final int savedCount;

  MeetingState copyWith({
    String? source,
    String? target,
    EngineKind? Function()? engine,
    Map<EngineKind, EngineBlock>? blocked,
    bool? running,
    bool? starting,
    bool? overlayShown,
    bool? inAppOnly,
    List<MeetingLine>? lines,
    MeetingBlock? Function()? block,
    int? savedCount,
  }) {
    return MeetingState(
      source: source ?? this.source,
      target: target ?? this.target,
      engine: engine != null ? engine() : this.engine,
      blocked: blocked ?? this.blocked,
      running: running ?? this.running,
      starting: starting ?? this.starting,
      overlayShown: overlayShown ?? this.overlayShown,
      inAppOnly: inAppOnly ?? this.inAppOnly,
      lines: lines ?? this.lines,
      block: block != null ? block() : this.block,
      savedCount: savedCount ?? this.savedCount,
    );
  }

  @override
  List<Object?> get props => [
    source,
    target,
    engine,
    blocked,
    running,
    starting,
    overlayShown,
    inAppOnly,
    lines,
    block,
    savedCount,
  ];
}

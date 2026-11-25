import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';
import '../../../../core/engines/live/live_access.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../model/listen_models.dart';

/// Listen screen state: languages, engine, whether the mic is on and the captions so far.
class ListenState extends Equatable {
  const ListenState({
    required this.source,
    required this.target,
    this.engine,
    this.blocked = const {},
    this.started = false,
    this.listening = false,
    this.captions = const [],
    this.block,
    this.switchedTo,
    this.switchCount = 0,
    this.liveDenial,
    this.liveStops = 0,
    this.draft,
  });

  final String? draft;

  final String source;
  final String target;
  final EngineKind? engine;
  final Map<EngineKind, EngineBlock> blocked;
  final bool started;
  final bool listening;
  final List<Caption> captions;
  final ListenBlock? block;
  final EngineKind? switchedTo;
  final int switchCount;
  final LiveDenial? liveDenial;
  final int liveStops;

  /// Whether a started session is paused: mic off, nothing counted (AC-03.6).
  bool get paused => started && !listening;

  ListenState copyWith({
    String? source,
    EngineKind? Function()? engine,
    Map<EngineKind, EngineBlock>? blocked,
    bool? started,
    bool? listening,
    List<Caption>? captions,
    ListenBlock? Function()? block,
    EngineKind? switchedTo,
    int? switchCount,
    LiveDenial? liveDenial,
    int? liveStops,
    String? Function()? draft,
  }) {
    return ListenState(
      source: source ?? this.source,
      target: target,
      engine: engine != null ? engine() : this.engine,
      blocked: blocked ?? this.blocked,
      started: started ?? this.started,
      listening: listening ?? this.listening,
      captions: captions ?? this.captions,
      block: block != null ? block() : this.block,
      switchedTo: switchedTo ?? this.switchedTo,
      switchCount: switchCount ?? this.switchCount,
      liveDenial: liveDenial ?? this.liveDenial,
      liveStops: liveStops ?? this.liveStops,
      draft: draft != null ? draft() : this.draft,
    );
  }

  @override
  List<Object?> get props => [
    source,
    target,
    engine,
    blocked,
    started,
    listening,
    captions,
    block,
    switchedTo,
    switchCount,
    liveDenial,
    liveStops,
    draft,
  ];
}

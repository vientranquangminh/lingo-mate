import 'package:equatable/equatable.dart';

import '../../../../core/engines/engines.dart';
import '../../../../core/engines/live/live_access.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../model/conversation_models.dart';

/// Split-screen conversation: who is talking, the turns so far and the engine in use.
class ConversationState extends Equatable {
  const ConversationState({
    required this.pair,
    this.listening,
    this.auto = false,
    this.processing = false,
    this.speaking = false,
    this.speakOn = true,
    this.turns = const [],
    this.engine,
    this.blocked = const {},
    this.switchedTo,
    this.switchCount = 0,
    this.paused,
    this.liveDenial,
    this.liveStops = 0,
  });

  final LanguagePair pair;
  final Speaker? listening;
  final bool auto;
  final bool processing;
  final bool speaking;
  final bool speakOn;
  final List<ConversationTurn> turns;
  final EngineKind? engine;
  final Map<EngineKind, EngineBlock> blocked;
  final EngineKind? switchedTo;
  final int switchCount;
  final PauseReason? paused;
  final LiveDenial? liveDenial;
  final int liveStops;

  /// Whether Live is translating both sides through one open mic.
  bool get liveListening => auto && engine == EngineKind.live;

  /// Returns the language [speaker] speaks.
  String languageOf(Speaker speaker) => speaker == Speaker.a ? pair.a : pair.b;

  /// The latest turn spoken by [speaker].
  ConversationTurn? lastBy(Speaker speaker) =>
      turns.where((t) => t.speaker == speaker).lastOrNull;

  ConversationState copyWith({
    Speaker? Function()? listening,
    bool? auto,
    bool? processing,
    bool? speaking,
    bool? speakOn,
    List<ConversationTurn>? turns,
    EngineKind? Function()? engine,
    Map<EngineKind, EngineBlock>? blocked,
    EngineKind? switchedTo,
    int? switchCount,
    PauseReason? Function()? paused,
    LiveDenial? liveDenial,
    int? liveStops,
  }) {
    return ConversationState(
      pair: pair,
      listening: listening != null ? listening() : this.listening,
      auto: auto ?? this.auto,
      processing: processing ?? this.processing,
      speaking: speaking ?? this.speaking,
      speakOn: speakOn ?? this.speakOn,
      turns: turns ?? this.turns,
      engine: engine != null ? engine() : this.engine,
      blocked: blocked ?? this.blocked,
      switchedTo: switchedTo ?? this.switchedTo,
      switchCount: switchCount ?? this.switchCount,
      paused: paused != null ? paused() : this.paused,
      liveDenial: liveDenial ?? this.liveDenial,
      liveStops: liveStops ?? this.liveStops,
    );
  }

  @override
  List<Object?> get props => [
    pair,
    listening,
    auto,
    processing,
    speaking,
    speakOn,
    turns,
    engine,
    blocked,
    switchedTo,
    switchCount,
    paused,
    liveDenial,
    liveStops,
  ];
}

import 'package:equatable/equatable.dart';

import '../engines.dart';
import 'capability_matrix.dart';

/// Translation mode the engine is chosen for.
enum SessionMode { conversation, listen, meeting }

/// Why an engine was not chosen; the engine sheet turns these into actions (AC-05.7).
enum EngineBlock {
  notSupported,
  noInternet,
  regionBlocked,
  liveDisabled,
  liveQuota,
  standardQuota,
  standardFailing,
  packsMissing,
}

/// The language pair of a session; in Conversation both sides are spoken.
class LanguagePair extends Equatable {
  const LanguagePair(this.a, this.b);

  final String a;
  final String b;

  /// Languages heard through the mic in [mode].
  Set<String> spokenIn(SessionMode mode) =>
      mode == SessionMode.conversation ? {a, b} : {a};

  @override
  List<Object?> get props => [a, b];
}

/// Everything the selector looks at, gathered from settings, connectivity, quota and packs.
class EngineSelectionInput extends Equatable {
  const EngineSelectionInput({
    required this.mode,
    required this.pair,
    required this.matrix,
    this.engineOrder = const [EngineKind.standard, EngineKind.offline],
    this.pinned,
    this.online = true,
    this.cloudBlockedForRegion = false,
    this.liveEnabled = false,
    this.liveQuotaOk = true,
    this.standardQuotaOk = true,
    this.standardFailing = false,
    this.packsInstalled = false,
  });

  final SessionMode mode;
  final LanguagePair pair;
  final CapabilityMatrix matrix;
  final List<EngineKind> engineOrder;
  final EngineKind? pinned;
  final bool online;
  final bool cloudBlockedForRegion;
  final bool liveEnabled;
  final bool liveQuotaOk;
  final bool standardQuotaOk;
  final bool standardFailing;
  final bool packsInstalled;

  @override
  List<Object?> get props => [
    mode,
    pair,
    matrix,
    engineOrder,
    pinned,
    online,
    cloudBlockedForRegion,
    liveEnabled,
    liveQuotaOk,
    standardQuotaOk,
    standardFailing,
    packsInstalled,
  ];
}

/// The selector's answer: the chosen engine, if any, and why each other engine was skipped.
class EngineSelection extends Equatable {
  const EngineSelection({required this.engine, required this.blocked});

  final EngineKind? engine;
  final Map<EngineKind, EngineBlock> blocked;

  bool get hasEngine => engine != null;

  @override
  List<Object?> get props => [engine, blocked];
}

/// Picks the engine for a session (doc 03 §7): the pinned engine, else the first usable one in order.
abstract final class EngineSelector {
  /// Returns the engine to use and the reason every engine is unavailable.
  static EngineSelection select(EngineSelectionInput input) {
    final blocked = <EngineKind, EngineBlock>{
      for (final engine in EngineKind.values) engine: ?_blockOf(engine, input),
    };
    final pinned = input.pinned;
    final order = pinned != null
        ? [pinned]
        : [
            if (input.liveEnabled) EngineKind.live,
            ...input.engineOrder.where((e) => e != EngineKind.live),
          ];
    final engine = order.where((e) => !blocked.containsKey(e)).firstOrNull;
    return EngineSelection(engine: engine, blocked: blocked);
  }

  /// Returns why [engine] cannot run now, or null when it can.
  static EngineBlock? _blockOf(EngineKind engine, EngineSelectionInput input) {
    final supported = input.matrix.supports(
      engine,
      from: input.pair.a,
      to: input.pair.b,
      spoken: input.pair.spokenIn(input.mode),
    );
    if (!supported) {
      return EngineBlock.notSupported;
    }
    if (engine != EngineKind.offline) {
      if (!input.online) {
        return EngineBlock.noInternet;
      }
      if (input.cloudBlockedForRegion) {
        return EngineBlock.regionBlocked;
      }
    }
    return switch (engine) {
      EngineKind.live when !input.liveEnabled => EngineBlock.liveDisabled,
      EngineKind.live when !input.liveQuotaOk => EngineBlock.liveQuota,
      EngineKind.standard when !input.standardQuotaOk =>
        EngineBlock.standardQuota,
      EngineKind.standard when input.standardFailing =>
        EngineBlock.standardFailing,
      EngineKind.offline when !input.packsInstalled => EngineBlock.packsMissing,
      _ => null,
    };
  }
}

/// Tracks Standard failures: 3 within 30 s switch to Offline, and Standard is retried after 60 s (AC-05.4).
class ErrorBurstTracker {
  ErrorBurstTracker({
    this.threshold = 3,
    this.window = const Duration(seconds: 30),
    this.cooldown = const Duration(seconds: 60),
  });

  final int threshold;
  final Duration window;
  final Duration cooldown;
  final _failures = <DateTime>[];
  DateTime? _burstAt;

  /// Records a failure at [now].
  void recordFailure(DateTime now) {
    _failures
      ..add(now)
      ..removeWhere((t) => now.difference(t) > window);
    if (_failures.length >= threshold) {
      _burstAt = now;
      _failures.clear();
    }
  }

  /// Records a success, forgetting earlier failures.
  void recordSuccess() => _failures.clear();

  /// Whether Standard should stay off at [now].
  bool isFailing(DateTime now) {
    final burstAt = _burstAt;
    if (burstAt == null) {
      return false;
    }
    if (now.difference(burstAt) >= cooldown) {
      _burstAt = null;
      return false;
    }
    return true;
  }
}

/// Remembers a "User location is not supported" error and disables cloud engines for 24 h (AC-05.5).
class RegionBlock {
  RegionBlock({this._blockedUntil, this.duration = const Duration(hours: 24)});

  final Duration duration;
  DateTime? _blockedUntil;

  DateTime? get blockedUntil => _blockedUntil;

  /// Starts the block at [now].
  void block(DateTime now) => _blockedUntil = now.add(duration);

  /// Whether cloud engines are blocked at [now].
  bool isBlocked(DateTime now) {
    final until = _blockedUntil;
    return until != null && now.isBefore(until);
  }
}

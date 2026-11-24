import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../flavor_config.dart';
import '../../config/remote_config_service.dart';
import '../../di/di.dart';
import '../../errors/crash_reporter.dart';
import '../engines.dart';
import '../translate/mlkit_text_translator.dart';
import 'capability_matrix.dart';
import 'engine_selector.dart';

/// Remote Config values for engine selection.
final engineRemoteConfigProvider = Provider<RemoteConfigService>(
  (ref) => getIt<RemoteConfigService>(),
);

/// Whether any network is connected.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});

/// The per-language capability matrix (Remote Config override or bundled default).
final capabilityMatrixProvider = FutureProvider<CapabilityMatrix>(
  (ref) => CapabilityMatrixLoader(
    ref.watch(engineRemoteConfigProvider),
    getIt<CrashReporter>(),
  ).load(),
);

/// Whether Live may be offered: dev flavor with `ff_live_enabled` on; never in other flavors in P1 (AC-05.6).
final liveAvailableProvider = Provider<bool>(
  (ref) =>
      FlavorConfig.instance.appFlavor == Flavor.development &&
      ref.watch(engineRemoteConfigProvider).liveEnabled,
);

/// Engine pinned by the user for this session (or by devtools); null means automatic.
final enginePinProvider = NotifierProvider<EnginePinNotifier, EngineKind?>(
  EnginePinNotifier.new,
);

/// Holds the pinned engine.
class EnginePinNotifier extends Notifier<EngineKind?> {
  @override
  EngineKind? build() => null;

  /// Pins [engine], or returns to automatic selection with null.
  void pin(EngineKind? engine) => state = engine;
}

/// Persists the 24 h region block so it survives restarts (AC-05.5).
final regionBlockProvider =
    AsyncNotifierProvider<RegionBlockNotifier, RegionBlock>(
      RegionBlockNotifier.new,
    );

/// Loads and saves the region block.
class RegionBlockNotifier extends AsyncNotifier<RegionBlock> {
  static const _key = 'cloud_region_blocked_until';

  @override
  Future<RegionBlock> build() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_key);
    return RegionBlock(
      blockedUntil: until == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  /// Blocks cloud engines from [now] and saves the end time.
  Future<void> block(DateTime now) async {
    final block = RegionBlock()..block(now);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, block.blockedUntil!.millisecondsSinceEpoch);
    state = AsyncData(block);
  }
}

/// Standard error bursts shared by every session.
final errorBurstProvider = Provider<ErrorBurstTracker>(
  (ref) => ErrorBurstTracker(),
);

/// Whether the Offline models for a pair are on the device (ML Kit; ASR packs join with T-1.3).
final packsInstalledProvider = FutureProvider.family<bool, LanguagePair>(
  (ref, pair) => MlKitTextTranslator().isAvailable(pair.a, pair.b),
);

/// What a session asks the selector for.
class EngineRequest extends Equatable {
  const EngineRequest({required this.mode, required this.pair});

  final SessionMode mode;
  final LanguagePair pair;

  @override
  List<Object?> get props => [mode, pair];
}

/// The engine to use for a session, re-evaluated when connectivity, packs, the pin or the region block change.
final engineSelectionProvider =
    FutureProvider.family<EngineSelection, EngineRequest>((ref, request) async {
      final now = DateTime.now();
      final regionBlock = await ref.watch(regionBlockProvider.future);
      return EngineSelector.select(
        EngineSelectionInput(
          mode: request.mode,
          pair: request.pair,
          matrix: await ref.watch(capabilityMatrixProvider.future),
          pinned: ref.watch(enginePinProvider),
          online: await ref.watch(onlineProvider.future),
          cloudBlockedForRegion: regionBlock.isBlocked(now),
          liveEnabled: ref.watch(liveAvailableProvider),
          standardFailing: ref.watch(errorBurstProvider).isFailing(now),
          packsInstalled: await ref.watch(
            packsInstalledProvider(request.pair).future,
          ),
        ),
      );
    });

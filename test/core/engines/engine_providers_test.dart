import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/settings/app_preferences.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/capability_matrix.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final matrix = CapabilityMatrix.fromJson(
    jsonDecode(File(CapabilityMatrix.assetPath).readAsStringSync())
        as Map<String, dynamic>,
  );
  late SharedPreferences prefs;
  const request = EngineRequest(
    mode: SessionMode.conversation,
    pair: LanguagePair('vi', 'en'),
  );

  /// Builds a container with fake connectivity, packs and Remote Config.
  ProviderContainer build({
    bool online = true,
    bool packs = true,
    EnginePreference engine = EnginePreference.auto,
    bool allowLive = true,
  }) {
    prefs
      ..setString('pref_engine', engine.name)
      ..setBool('pref_allow_live', allowLive);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        onlineProvider.overrideWith((ref) => Stream.value(online)),
        capabilityMatrixProvider.overrideWith((ref) async => matrix),
        packsInstalledProvider.overrideWith((ref, pair) async => packs),
        engineRemoteConfigProvider.overrideWithValue(
          RemoteConfigService.withDefaults(CrashReporter.disabled()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    FlavorConfig(appFlavor: Flavor.production);
  });

  test(
    'Prefer Offline picks Offline online when packs cover the pair (AC-10.2)',
    () async {
      expect(
        (await build(engine: EnginePreference.preferOffline)
                .read(engineSelectionProvider(request).future))
            .engine,
        EngineKind.offline,
      );
      expect(
        (await build(
          engine: EnginePreference.preferOffline,
          packs: false,
        ).read(engineSelectionProvider(request).future)).engine,
        EngineKind.standard,
      );
      expect(
        (await build(engine: EnginePreference.preferStandard)
                .read(engineSelectionProvider(request).future))
            .engine,
        EngineKind.standard,
      );
    },
  );

  test('picks Standard online and Offline without internet', () async {
    expect(
      (await build().read(engineSelectionProvider(request).future)).engine,
      EngineKind.standard,
    );
    expect(
      (await build(online: false).read(engineSelectionProvider(request).future))
          .engine,
      EngineKind.offline,
    );
  });

  test('a pinned engine wins', () async {
    final c = build();
    c.read(enginePinProvider.notifier).pin(EngineKind.offline);

    expect(
      (await c.read(engineSelectionProvider(request).future)).engine,
      EngineKind.offline,
    );
  });

  test('Live is offered in the dev flavor only (AC-05.6)', () async {
    expect(build().read(liveAvailableProvider), isFalse);

    FlavorConfig(appFlavor: Flavor.development);
    final dev = build();

    expect(dev.read(liveAvailableProvider), isTrue);
    expect(
      (await dev.read(engineSelectionProvider(request).future)).engine,
      EngineKind.live,
    );
    expect(
      (await build(allowLive: false)
              .read(engineSelectionProvider(request).future))
          .engine,
      EngineKind.standard,
    );
  });

  test('the region block is saved and blocks cloud engines', () async {
    final c = build();
    await c.read(regionBlockProvider.future);

    await c.read(regionBlockProvider.notifier).block(DateTime.now());
    final selection = await c.read(engineSelectionProvider(request).future);

    expect(selection.engine, EngineKind.offline);
    expect(selection.blocked[EngineKind.standard], EngineBlock.regionBlocked);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('cloud_region_blocked_until'), isNotNull);

    final restarted = build();
    final block = await restarted.read(regionBlockProvider.future);
    expect(block.isBlocked(DateTime.now()), isTrue);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  const request = EngineRequest(
    mode: SessionMode.conversation,
    pair: LanguagePair('vi', 'en'),
  );

  /// Builds a container with fake connectivity, packs and Remote Config.
  ProviderContainer build({bool online = true, bool packs = true}) {
    final c = ProviderContainer(
      overrides: [
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlavorConfig(appFlavor: Flavor.production);
  });

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

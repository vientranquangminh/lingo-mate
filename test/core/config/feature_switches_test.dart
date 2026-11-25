import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/feature_switches.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/config/remote_defaults.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/flavor_config.dart';

void main() {
  setUp(() => FlavorConfig(appFlavor: Flavor.production));

  /// Reads the switches with [overrides] on top of the in-app defaults.
  FeatureSwitches read(Map<String, Object> overrides) {
    final container = ProviderContainer(
      overrides: [
        engineRemoteConfigProvider.overrideWithValue(
          RemoteConfigService.withDefaults(CrashReporter.disabled(), overrides),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container.read(featureSwitchesProvider);
  }

  test('paid features are on by default; the review waits for its flag', () {
    expect(read(const {}), const FeatureSwitches());
  });

  test('each paid feature follows its own Remote Config key', () {
    expect(
      read({
        RemoteDefaults.ffStandardEnabled: false,
        RemoteDefaults.ffSummary: false,
        RemoteDefaults.ffSuggestReply: false,
        RemoteDefaults.ffGlossary: false,
        RemoteDefaults.ffPostSessionReview: true,
        RemoteDefaults.ffCloudSpeech: false,
      }),
      const FeatureSwitches(
        standard: false,
        summary: false,
        suggestReply: false,
        glossary: false,
        postSessionReview: true,
        cloudSpeech: false,
      ),
    );
  });
}

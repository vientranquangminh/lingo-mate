import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/config/remote_defaults.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/flavor_config.dart';

/// A crash reporter that keeps the reasons it was given.
class _RecordingCrashReporter extends CrashReporter {
  _RecordingCrashReporter() : super.disabled();

  final reasons = <String?>[];

  @override
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    reasons.add(reason);
  }
}

void main() {
  late _RecordingCrashReporter reporter;

  setUp(() {
    reporter = _RecordingCrashReporter();
  });

  test('falls back to the in-app defaults without Firebase', () {
    FlavorConfig(appFlavor: Flavor.production);
    final service = RemoteConfigService.withDefaults(reporter);

    expect(service.modelTextTranslate, 'gemini-2.5-flash-lite');
    expect(service.modelLiveTranslate, 'gemini-3.5-live-translate-preview');
    expect(service.liveBlockSec, 600);
    expect(service.liveEnabled, isFalse);
    expect(service.meetingOverlayEnabled, isTrue);
    expect(service.capabilityMatrix, isNull);
  });

  test('live is enabled by default in the dev flavor', () {
    FlavorConfig(appFlavor: Flavor.development);

    expect(RemoteConfigService.withDefaults(reporter).liveEnabled, isTrue);
  });

  test('parses the quota limits', () {
    final service = RemoteConfigService.withDefaults(reporter);

    final free = service.quotaLimits['free'] as Map<String, dynamic>;

    expect((free['standard'] as Map)['win5hSec'], 1800);
    expect(reporter.reasons, isEmpty);
  });

  test('keeps the default quota limits and reports malformed JSON', () {
    final service = RemoteConfigService.withDefaults(reporter, {
      RemoteDefaults.quotaLimits: '{not json',
    });

    expect(service.quotaLimits.keys, containsAll(['free', 'pro']));
    expect(reporter.reasons, ['remote json ${RemoteDefaults.quotaLimits}']);
  });

  test('returns a capability matrix override', () {
    final service = RemoteConfigService.withDefaults(reporter, {
      RemoteDefaults.capabilityMatrix: '{"vi":{"live":true}}',
    });

    expect(service.capabilityMatrix, {
      'vi': {'live': true},
    });
  });
}

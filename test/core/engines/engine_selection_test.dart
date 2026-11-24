import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/config/remote_defaults.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/capability_matrix.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';

/// A crash reporter that counts non-fatal reports.
class _CountingReporter extends CrashReporter {
  _CountingReporter() : super.disabled();

  int reports = 0;

  @override
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async => reports++;
}

void main() {
  final asset = File(CapabilityMatrix.assetPath).readAsStringSync();
  final matrix = CapabilityMatrix.fromJson(
    jsonDecode(asset) as Map<String, dynamic>,
  );
  final withKhmer = CapabilityMatrix.fromJson({
    'version': 2,
    'languages': {
      'vi': {'offlineTranslate': true, 'asrOnDevice': 'good', 'live': true},
      'km': {'offlineTranslate': false, 'asrOnDevice': 'poor', 'live': true},
      'en': {'offlineTranslate': true, 'asrOnDevice': 'good', 'live': true},
    },
  });

  group('CapabilityMatrix', () {
    test('the bundled default lists the ten wave-1 languages', () {
      expect(matrix.languages.keys.toSet(), {
        'en', 'vi', 'ja', 'ko', 'zh', 'th', 'id', 'es', 'fr', 'de', //
      });
      expect(matrix.languages['vi']!.asrOnDevice, AsrQuality.good);
      expect(matrix.languages.values.every((l) => l.wave == 1), isTrue);
    });

    test('poor on-device ASR leaves only Live', () {
      expect(withKhmer.supports(EngineKind.live, from: 'km', to: 'vi'), isTrue);
      expect(
        withKhmer.supports(EngineKind.standard, from: 'km', to: 'vi'),
        isFalse,
      );
      expect(
        withKhmer.supports(EngineKind.offline, from: 'km', to: 'vi'),
        isFalse,
      );
    });

    test('Offline needs ML Kit on both sides even when only one is spoken', () {
      expect(
        withKhmer.supports(EngineKind.offline, from: 'vi', to: 'km'),
        isFalse,
      );
      expect(
        withKhmer.supports(EngineKind.standard, from: 'vi', to: 'km'),
        isTrue,
      );
      expect(
        withKhmer.supports(
          EngineKind.standard,
          from: 'vi',
          to: 'km',
          spoken: {'vi', 'km'},
        ),
        isFalse,
      );
    });

    test('unknown languages and same-language pairs are unsupported', () {
      expect(matrix.supports(EngineKind.live, from: 'xx', to: 'en'), isFalse);
      expect(matrix.supports(EngineKind.live, from: 'en', to: 'en'), isFalse);
    });

    test('unknown ASR quality counts as none', () {
      expect(AsrQuality.parse('great'), AsrQuality.none);
    });

    test('rejects JSON without languages', () {
      expect(
        () => CapabilityMatrix.fromJson({'version': 1}),
        throwsFormatException,
      );
    });
  });

  group('CapabilityMatrixLoader', () {
    test('uses a valid Remote Config override', () async {
      final reporter = _CountingReporter();
      final loader = CapabilityMatrixLoader(
        RemoteConfigService.withDefaults(reporter, {
          RemoteDefaults.capabilityMatrix: jsonEncode({
            'version': 9,
            'languages': {
              'vi': {'live': true},
            },
          }),
        }),
        reporter,
        readAsset: () async => asset,
      );

      expect((await loader.load()).version, 9);
    });

    test('keeps the bundled matrix and reports a malformed override', () async {
      final reporter = _CountingReporter();
      final loader = CapabilityMatrixLoader(
        RemoteConfigService.withDefaults(reporter, {
          RemoteDefaults.capabilityMatrix: '{"version": 9}',
        }),
        reporter,
        readAsset: () async => asset,
      );

      expect(await loader.load(), matrix);
      expect(reporter.reports, 1);
    });

    test('uses the bundled matrix without an override', () async {
      final reporter = _CountingReporter();
      final loader = CapabilityMatrixLoader(
        RemoteConfigService.withDefaults(reporter),
        reporter,
        readAsset: () async => asset,
      );

      expect(await loader.load(), matrix);
      expect(reporter.reports, 0);
    });
  });

  group('EngineSelector', () {
    const viEn = LanguagePair('vi', 'en');

    /// Selects with defaults: online, packs installed, Conversation vi↔en.
    EngineSelection select({
      CapabilityMatrix? m,
      LanguagePair pair = viEn,
      bool online = true,
      bool packs = true,
      bool regionBlocked = false,
      bool liveEnabled = false,
      bool liveQuotaOk = true,
      bool standardQuotaOk = true,
      bool standardFailing = false,
      EngineKind? pinned,
    }) => EngineSelector.select(
      EngineSelectionInput(
        mode: SessionMode.conversation,
        pair: pair,
        matrix: m ?? matrix,
        online: online,
        packsInstalled: packs,
        cloudBlockedForRegion: regionBlocked,
        liveEnabled: liveEnabled,
        liveQuotaOk: liveQuotaOk,
        standardQuotaOk: standardQuotaOk,
        standardFailing: standardFailing,
        pinned: pinned,
      ),
    );

    test('Auto picks Standard online with packs installed (AC-05.2)', () {
      final s = select();

      expect(s.engine, EngineKind.standard);
      expect(s.blocked[EngineKind.live], EngineBlock.liveDisabled);
    });

    test('Auto picks Offline without internet (AC-05.2)', () {
      final s = select(online: false);

      expect(s.engine, EngineKind.offline);
      expect(s.blocked[EngineKind.standard], EngineBlock.noInternet);
    });

    test('never picks Offline when the language lacks it (AC-05.3)', () {
      final s = select(
        m: withKhmer,
        pair: const LanguagePair('km', 'vi'),
        online: false,
      );

      expect(s.engine, isNull);
      expect(s.blocked[EngineKind.offline], EngineBlock.notSupported);
    });

    test('a region block disables the cloud engines (AC-05.5)', () {
      final s = select(regionBlocked: true, liveEnabled: true);

      expect(s.engine, EngineKind.offline);
      expect(s.blocked[EngineKind.standard], EngineBlock.regionBlocked);
      expect(s.blocked[EngineKind.live], EngineBlock.regionBlocked);
    });

    test('a Standard error burst falls back to Offline (AC-05.4)', () {
      final s = select(standardFailing: true);

      expect(s.engine, EngineKind.offline);
      expect(s.blocked[EngineKind.standard], EngineBlock.standardFailing);
    });

    test('Live comes first when enabled, and gives way when out of quota', () {
      expect(select(liveEnabled: true).engine, EngineKind.live);

      final noQuota = select(liveEnabled: true, liveQuotaOk: false);
      expect(noQuota.engine, EngineKind.standard);
      expect(noQuota.blocked[EngineKind.live], EngineBlock.liveQuota);
    });

    test('Standard out of quota falls back to Offline', () {
      expect(select(standardQuotaOk: false).engine, EngineKind.offline);
    });

    test('Offline without packs explains what is missing', () {
      final s = select(online: false, packs: false);

      expect(s.engine, isNull);
      expect(s.blocked[EngineKind.offline], EngineBlock.packsMissing);
      expect(s.hasEngine, isFalse);
    });

    test('a pinned engine is used, or nothing when it is blocked', () {
      expect(select(pinned: EngineKind.offline).engine, EngineKind.offline);

      final blocked = select(pinned: EngineKind.offline, packs: false);
      expect(blocked.engine, isNull);
    });
  });

  group('ErrorBurstTracker', () {
    final t0 = DateTime(2026, 11, 24, 9);

    test('three failures within 30 s stop Standard for 60 s', () {
      final tracker = ErrorBurstTracker()
        ..recordFailure(t0)
        ..recordFailure(t0.add(const Duration(seconds: 10)))
        ..recordFailure(t0.add(const Duration(seconds: 20)));

      expect(tracker.isFailing(t0.add(const Duration(seconds: 21))), isTrue);
      expect(tracker.isFailing(t0.add(const Duration(seconds: 79))), isTrue);
      expect(tracker.isFailing(t0.add(const Duration(seconds: 80))), isFalse);
    });

    test('failures spread over more than 30 s do not count', () {
      final tracker = ErrorBurstTracker()
        ..recordFailure(t0)
        ..recordFailure(t0.add(const Duration(seconds: 20)))
        ..recordFailure(t0.add(const Duration(seconds: 40)));

      expect(tracker.isFailing(t0.add(const Duration(seconds: 41))), isFalse);
    });

    test('a success resets the count', () {
      final tracker = ErrorBurstTracker()
        ..recordFailure(t0)
        ..recordFailure(t0.add(const Duration(seconds: 1)))
        ..recordSuccess()
        ..recordFailure(t0.add(const Duration(seconds: 2)));

      expect(tracker.isFailing(t0.add(const Duration(seconds: 3))), isFalse);
    });
  });

  group('RegionBlock', () {
    test('blocks cloud engines for 24 h', () {
      final now = DateTime(2026, 11, 24, 9);
      final block = RegionBlock()..block(now);

      expect(block.isBlocked(now.add(const Duration(hours: 23))), isTrue);
      expect(block.isBlocked(now.add(const Duration(hours: 24))), isFalse);
      expect(RegionBlock().isBlocked(now), isFalse);
    });
  });
}

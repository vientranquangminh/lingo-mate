import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/di.dart';
import '../errors/crash_reporter.dart';
import '../settings/app_preferences.dart';

/// Product events without any text (doc 03 §12), sent only while the user allows analytics (AC-10.4).
class AnalyticsService {
  AnalyticsService({AnalyticsSink? sink})
    : _sink =
          sink ??
          (Firebase.apps.isEmpty
              ? null
              : FirebaseAnalyticsSink(FirebaseAnalytics.instance));

  final AnalyticsSink? _sink;
  bool _enabled = false;

  /// Whether events are sent.
  bool get enabled => _enabled;

  /// Turns collection on or off.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _sink?.setCollectionEnabled(enabled);
  }

  /// A session started in [mode] on [engine] for [pair] (`vi-en`).
  Future<void> sessionStart({
    required String mode,
    required String engine,
    required String pair,
  }) => _log('session_start', {'mode': mode, 'engine': engine, 'pair': pair});

  /// A session ended after [durationSec] seconds.
  Future<void> sessionEnd({required String mode, required int durationSec}) =>
      _log('session_end', {'mode': mode, 'duration': durationSec});

  /// The engine changed during a session.
  Future<void> engineSwitch({
    required String from,
    required String to,
    required String reason,
  }) => _log('engine_switch', {'from': from, 'to': to, 'reason': reason});

  /// A phrase was saved from [source] (conversation, transcript, quick, manual).
  Future<void> phraseSaved({required String source}) =>
      _log('phrase_saved', {'source': source});

  /// Sends [name] with [parameters] when allowed.
  Future<void> _log(String name, Map<String, Object> parameters) async {
    if (!_enabled) {
      return;
    }
    await _sink?.log(name, parameters);
  }
}

/// Where analytics events go.
abstract interface class AnalyticsSink {
  /// Turns collection on or off at the source.
  Future<void> setCollectionEnabled(bool enabled);

  /// Records one event.
  Future<void> log(String name, Map<String, Object> parameters);
}

/// [AnalyticsSink] on Firebase Analytics.
class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalyticsSink(this._analytics);

  final FirebaseAnalytics _analytics;

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> log(String name, Map<String, Object> parameters) =>
      _analytics.logEvent(name: name, parameters: parameters);
}

/// The app's analytics.
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);

/// The app's crash reporter.
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => getIt.isRegistered<CrashReporter>()
      ? getIt<CrashReporter>()
      : CrashReporter.disabled(),
);

/// Applies the analytics and crash reporting choices whenever they change.
final privacyConsentProvider = Provider<void>((ref) {
  final prefs = ref.watch(appPreferencesProvider);
  ref.read(analyticsProvider).setEnabled(prefs.analytics);
  ref.read(crashReporterProvider).setEnabled(prefs.crashReports);
});

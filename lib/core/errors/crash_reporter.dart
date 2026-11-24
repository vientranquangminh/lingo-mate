import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Sends crashes and non-fatal errors to Crashlytics, never transcript text.
@lazySingleton
class CrashReporter {
  CrashReporter()
    : _crashlytics = Firebase.apps.isEmpty
          ? null
          : FirebaseCrashlytics.instance;

  CrashReporter.disabled() : _crashlytics = null;

  final FirebaseCrashlytics? _crashlytics;

  /// Routes uncaught Flutter and platform errors to Crashlytics.
  Future<void> installErrorHandlers() async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = crashlytics.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Records a handled error.
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    if (_crashlytics == null) {
      if (kDebugMode) {
        debugPrint('Non-fatal ($reason): $error');
      }
      return;
    }
    await _crashlytics.recordError(error, stack, reason: reason);
  }

  /// Sets the engine, mode and language pair keys attached to later reports.
  Future<void> setContext({String? engine, String? mode, String? pair}) async {
    final crashlytics = _crashlytics;
    if (crashlytics == null) {
      return;
    }
    if (engine != null) {
      await crashlytics.setCustomKey('engine', engine);
    }
    if (mode != null) {
      await crashlytics.setCustomKey('mode', mode);
    }
    if (pair != null) {
      await crashlytics.setCustomKey('pair', pair);
    }
  }
}

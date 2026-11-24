import 'package:flutter/services.dart';

/// Something the foreground service or the caption overlay reported.
sealed class BackgroundEvent {
  const BackgroundEvent();
}

/// Stop was pressed in the notification.
class BackgroundStopPressed extends BackgroundEvent {
  const BackgroundStopPressed();
}

/// A caption line was long-pressed in the overlay.
class OverlayLineLongPressed extends BackgroundEvent {
  const OverlayLineLongPressed(this.text);

  final String text;
}

/// Keeps capture alive in the background and shows floating captions (Meeting mode, doc 03 §6.4).
abstract interface class BackgroundCapture {
  /// Events from the notification and the overlay.
  Stream<BackgroundEvent> get events;

  /// Starts the microphone foreground service with its notification.
  Future<void> startService();

  /// Stops the service and removes the notification.
  Future<void> stopService();

  /// Whether the app may draw the caption overlay.
  Future<bool> canDrawOverlays();

  /// Opens the system overlay permission screen.
  Future<void> openOverlaySettings();

  /// Shows the caption bubble; returns false without permission.
  Future<bool> showOverlay();

  /// Replaces the caption lines in the bubble.
  Future<void> updateOverlay(List<String> lines);

  /// Removes the caption bubble.
  Future<void> hideOverlay();
}

/// [BackgroundCapture] backed by `TranslationForegroundService` and `CaptionOverlay` on Android.
class NativeBackgroundCapture implements BackgroundCapture {
  const NativeBackgroundCapture();

  static const _methods = MethodChannel('lingomate/background');
  static const _events = EventChannel('lingomate/background/events');

  @override
  Stream<BackgroundEvent> get events => _events
      .receiveBroadcastStream()
      .map((raw) => Map<String, Object?>.from(raw as Map))
      .map<BackgroundEvent?>(
        (e) => switch (e['type']) {
          'stop' => const BackgroundStopPressed(),
          'longPress' => OverlayLineLongPressed(e['text'] as String? ?? ''),
          _ => null,
        },
      )
      .where((e) => e != null)
      .cast<BackgroundEvent>();

  @override
  Future<void> startService() => _methods.invokeMethod('startService');

  @override
  Future<void> stopService() => _methods.invokeMethod('stopService');

  @override
  Future<bool> canDrawOverlays() async =>
      await _methods.invokeMethod<bool>('canDrawOverlays') ?? false;

  @override
  Future<void> openOverlaySettings() =>
      _methods.invokeMethod('openOverlaySettings');

  @override
  Future<bool> showOverlay() async =>
      await _methods.invokeMethod<bool>('showOverlay') ?? false;

  @override
  Future<void> updateOverlay(List<String> lines) =>
      _methods.invokeMethod('updateOverlay', {'lines': lines});

  @override
  Future<void> hideOverlay() => _methods.invokeMethod('hideOverlay');
}

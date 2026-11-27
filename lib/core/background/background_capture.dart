import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Something the foreground service or the caption overlay reported.
sealed class BackgroundEvent {
  const BackgroundEvent();
}

/// Stop was pressed in the notification or the overlay.
class BackgroundStopPressed extends BackgroundEvent {
  const BackgroundStopPressed();
}

/// A caption line was long-pressed in the overlay; [index] is its position in the lines last sent.
class OverlayLineLongPressed extends BackgroundEvent {
  const OverlayLineLongPressed(this.text, {this.index});

  final String text;
  final int? index;
}

/// One caption in the overlay: what was said, its translation and, when told apart, its speaker.
class OverlayLine {
  const OverlayLine({
    required this.original,
    required this.translation,
    this.speaker,
    this.speakerLabel = '',
  });

  final String original;
  final String translation;
  final int? speaker;
  final String speakerLabel;

  /// The channel form of this line.
  Map<String, String> toMap() => {
    'original': original,
    'translation': translation,
    'speaker': '${speaker ?? 0}',
    'speakerLabel': speakerLabel,
  };
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

  /// Replaces the caption lines in the bubble and the engine in its header ([engine] is the kind name, [engineLabel] what is shown).
  Future<void> updateOverlay(
    List<OverlayLine> lines, {
    String engine = '',
    String engineLabel = '',
  });

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
          'longPress' => OverlayLineLongPressed(
            e['text'] as String? ?? '',
            index: e['index'] as int?,
          ),
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
  Future<void> updateOverlay(
    List<OverlayLine> lines, {
    String engine = '',
    String engineLabel = '',
  }) => _methods.invokeMethod('updateOverlay', {
    'lines': [for (final line in lines) line.toMap()],
    'engine': engine,
    'engineLabel': engineLabel,
  });

  @override
  Future<void> hideOverlay() => _methods.invokeMethod('hideOverlay');
}

/// The foreground service and caption overlay.
final backgroundCaptureProvider = Provider<BackgroundCapture>(
  (ref) => const NativeBackgroundCapture(),
);

/// Asks for the notification permission the foreground service needs on Android 13+.
final notificationPermissionProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => Permission.notification.request(),
);

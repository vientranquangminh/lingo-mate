import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Android system screens (settings pages, the share sheet) and keeps the screen on (`SystemSettingsChannel.kt`).
abstract interface class SystemSettings {
  /// Opens the screen that installs text-to-speech voices; returns false when none opened.
  Future<bool> installTtsVoice();

  /// Opens this app's page in system settings, where permissions are granted.
  Future<bool> openAppSettings();

  /// Opens the system share sheet with [text]; [subject] titles it where apps support one.
  Future<bool> shareText(String text, {String? subject});

  /// Keeps the screen awake while [on], for live sessions.
  Future<bool> keepScreenOn(bool on);

  /// Opens [url] in the browser; returns false when nothing opened it.
  Future<bool> openUrl(String url);
}

/// [SystemSettings] over the `lingomate/system_settings` channel.
class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings();

  static const _channel = MethodChannel('lingomate/system_settings');

  @override
  Future<bool> installTtsVoice() => _invoke('installTtsVoice');

  @override
  Future<bool> openAppSettings() => _invoke('openAppSettings');

  @override
  Future<bool> shareText(String text, {String? subject}) =>
      _invoke('shareText', {'text': text, 'subject': subject});

  @override
  Future<bool> keepScreenOn(bool on) => _invoke('keepScreenOn', {'on': on});

  @override
  Future<bool> openUrl(String url) => _invoke('openUrl', {'url': url});

  /// Calls [method] with [arguments]; returns false when the platform has no handler.
  Future<bool> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// System settings opener.
final systemSettingsProvider = Provider<SystemSettings>(
  (ref) => const ChannelSystemSettings(),
);

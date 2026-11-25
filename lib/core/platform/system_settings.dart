import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Android system screens: settings pages and the share sheet (`SystemSettingsChannel.kt`).
abstract interface class SystemSettings {
  /// Opens the screen that installs text-to-speech voices; returns false when none opened.
  Future<bool> installTtsVoice();

  /// Opens this app's page in system settings, where permissions are granted.
  Future<bool> openAppSettings();

  /// Opens the system share sheet with [text]; [subject] titles it where apps support one.
  Future<bool> shareText(String text, {String? subject});
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

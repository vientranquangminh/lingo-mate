import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Android system settings screens (`SystemSettingsChannel.kt`).
abstract interface class SystemSettings {
  /// Opens the screen that installs text-to-speech voices; returns false when none opened.
  Future<bool> installTtsVoice();

  /// Opens this app's page in system settings, where permissions are granted.
  Future<bool> openAppSettings();
}

/// [SystemSettings] over the `lingomate/system_settings` channel.
class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings();

  static const _channel = MethodChannel('lingomate/system_settings');

  @override
  Future<bool> installTtsVoice() => _invoke('installTtsVoice');

  @override
  Future<bool> openAppSettings() => _invoke('openAppSettings');

  /// Calls [method]; returns false when the platform has no handler.
  Future<bool> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
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

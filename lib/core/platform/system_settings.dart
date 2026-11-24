import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Android system settings screens (`SystemSettingsChannel.kt`).
abstract interface class SystemSettings {
  /// Opens the screen that installs text-to-speech voices; returns false when none opened.
  Future<bool> installTtsVoice();
}

/// [SystemSettings] over the `lingomate/system_settings` channel.
class ChannelSystemSettings implements SystemSettings {
  const ChannelSystemSettings();

  static const _channel = MethodChannel('lingomate/system_settings');

  @override
  Future<bool> installTtsVoice() async {
    try {
      return await _channel.invokeMethod<bool>('installTtsVoice') ?? false;
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

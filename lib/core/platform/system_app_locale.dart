import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The per-app language of Android 13+, shown in system Settings → App languages (`AppLocaleChannel.kt`).
abstract interface class SystemAppLocale {
  /// Returns the language tag chosen in system settings, '' when the app follows the phone, null where the platform has none.
  Future<String?> read();

  /// Sets the system's per-app language to [tag]; null follows the phone.
  Future<void> write(String? tag);
}

/// [SystemAppLocale] over the `lingomate/app_locale` channel.
class ChannelSystemAppLocale implements SystemAppLocale {
  const ChannelSystemAppLocale();

  static const _channel = MethodChannel('lingomate/app_locale');

  @override
  Future<String?> read() async {
    try {
      return await _channel.invokeMethod<String>('get');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> write(String? tag) async {
    try {
      await _channel.invokeMethod<bool>('set', {'tag': tag ?? ''});
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

/// The system's per-app language.
final systemAppLocaleProvider = Provider<SystemAppLocale>(
  (ref) => const ChannelSystemAppLocale(),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generated/l10n.dart';
import '../platform/system_app_locale.dart';
import 'user_settings.dart';

/// Keeps the in-app language and Android's per-app language in step (AC-11.6).
class AppLocaleSync {
  AppLocaleSync(this._ref);

  static const syncedKey = 'app_locale_system_synced';

  final Ref _ref;
  String? _system;
  bool _known = false;

  SystemAppLocale get _platform => _ref.read(systemAppLocaleProvider);

  /// Hands the in-app choice to the system on the first run, afterwards adopts the system's choice.
  Future<void> start() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (prefs.getBool(syncedKey) ?? false) {
      await pull();
      return;
    }
    final tag = await _platform.read();
    if (tag == null) {
      return;
    }
    await push(_ref.read(userSettingsProvider).appLocale);
    await prefs.setBool(syncedKey, true);
  }

  /// Adopts the language chosen in system settings when the app supports it.
  Future<void> pull() async {
    final tag = await _platform.read();
    if (tag == null) {
      return;
    }
    final code = tag.isEmpty ? null : tag.split(RegExp('[-_]')).first;
    _system = code;
    _known = true;
    final supported =
        code == null ||
        AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
    if (!supported || code == _ref.read(userSettingsProvider).appLocale) {
      return;
    }
    await _ref.read(userSettingsProvider.notifier).setAppLocale(code);
  }

  /// Sets the system's per-app language to [code] unless it already is.
  Future<void> push(String? code) async {
    if (_known && code == _system) {
      return;
    }
    _system = code;
    _known = true;
    await _platform.write(code);
  }
}

/// The language sync; pushes every in-app language change to the system.
final appLocaleSyncProvider = Provider<AppLocaleSync>((ref) {
  final sync = AppLocaleSync(ref);
  ref.listen(
    userSettingsProvider.select((s) => s.appLocale),
    (_, next) => sync.push(next),
  );
  return sync;
});

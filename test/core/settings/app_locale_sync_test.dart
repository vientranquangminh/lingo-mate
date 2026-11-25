import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/platform/system_app_locale.dart';
import 'package:lingo_mate/core/settings/app_locale_sync.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android's per-app language held in memory; null [tag] means a platform without one.
class _FakeSystemAppLocale implements SystemAppLocale {
  _FakeSystemAppLocale(this.tag);

  String? tag;
  final writes = <String?>[];

  @override
  Future<String?> read() async => tag;

  @override
  Future<void> write(String? tag) async {
    writes.add(tag);
    this.tag = tag ?? '';
  }
}

void main() {
  late SharedPreferences prefs;

  /// Builds a container over [system] with the given saved preferences.
  Future<ProviderContainer> build(
    _FakeSystemAppLocale system, [
    Map<String, Object> saved = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        systemAppLocaleProvider.overrideWithValue(system),
      ],
    );
    addTearDown(container.dispose);
    container.listen(appLocaleSyncProvider, (_, _) {});
    return container;
  }

  test('the first run hands the in-app choice to the system', () async {
    final system = _FakeSystemAppLocale('');
    final container = await build(system, {'app_locale': 'vi'});
    await container.read(appLocaleSyncProvider).start();
    expect(system.tag, 'vi');
    expect(prefs.getBool(AppLocaleSync.syncedKey), isTrue);
  });

  test('a choice made in system settings reaches the app on resume', () async {
    final system = _FakeSystemAppLocale('');
    final container = await build(system, {AppLocaleSync.syncedKey: true});
    final sync = container.read(appLocaleSyncProvider);
    await sync.start();
    expect(container.read(userSettingsProvider).appLocale, isNull);

    system.tag = 'vi-VN';
    await sync.pull();
    expect(container.read(userSettingsProvider).appLocale, 'vi');
    expect(system.writes, isEmpty);

    system.tag = '';
    await sync.pull();
    expect(container.read(userSettingsProvider).appLocale, isNull);
  });

  test('a choice made in the app reaches the system', () async {
    final system = _FakeSystemAppLocale('');
    final container = await build(system, {AppLocaleSync.syncedKey: true});
    await container.read(appLocaleSyncProvider).start();

    await container.read(userSettingsProvider.notifier).setAppLocale('vi');
    await Future<void>.delayed(Duration.zero);
    expect(system.tag, 'vi');

    await container.read(userSettingsProvider.notifier).setAppLocale(null);
    await Future<void>.delayed(Duration.zero);
    expect(system.writes, ['vi', null]);
  });

  test('an unsupported system language leaves the app setting alone', () async {
    final system = _FakeSystemAppLocale('fr');
    final container = await build(system, {
      AppLocaleSync.syncedKey: true,
      'app_locale': 'vi',
    });
    await container.read(appLocaleSyncProvider).start();
    expect(container.read(userSettingsProvider).appLocale, 'vi');
  });

  test('platforms without per-app languages change nothing', () async {
    final system = _FakeSystemAppLocale(null);
    final container = await build(system, {'app_locale': 'vi'});
    await container.read(appLocaleSyncProvider).start();
    expect(system.writes, isEmpty);
    expect(prefs.getBool(AppLocaleSync.syncedKey), isNull);
    expect(container.read(userSettingsProvider).appLocale, 'vi');
  });

  test('locales_config.xml declares exactly the supported languages', () {
    final xml = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();
    final declared = RegExp(
      r'<locale android:name="([^"]+)"',
    ).allMatches(xml).map((m) => m.group(1)).toSet();
    expect(
      declared,
      AppLocalizations.supportedLocales.map((l) => l.toLanguageTag()).toSet(),
    );
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:localeConfig="@xml/locales_config"'));
  });
}

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/di.dart';
import '../engines/selection/engine_selector.dart';

/// What the user set up: app language, own and partner languages, the current pair and onboarding progress.
class UserSettings extends Equatable {
  const UserSettings({
    this.onboardingDone = false,
    this.appLocale,
    this.myLanguage,
    this.partnerLanguages = const [],
    this.pairA,
    this.pairB,
    this.micDenials = 0,
  });

  final bool onboardingDone;
  final String? appLocale;
  final String? myLanguage;
  final List<String> partnerLanguages;
  final String? pairA;
  final String? pairB;
  final int micDenials;

  /// The language pair for the next session: the saved pair, else own language with the first partner language.
  LanguagePair get pair {
    final a = pairA ?? myLanguage ?? 'en';
    final b =
        pairB ??
        partnerLanguages.where((l) => l != a).firstOrNull ??
        (a == 'en' ? 'vi' : 'en');
    return LanguagePair(a, b);
  }

  UserSettings copyWith({
    bool? onboardingDone,
    String? Function()? appLocale,
    String? myLanguage,
    List<String>? partnerLanguages,
    String? Function()? pairA,
    String? Function()? pairB,
    int? micDenials,
  }) {
    return UserSettings(
      onboardingDone: onboardingDone ?? this.onboardingDone,
      appLocale: appLocale != null ? appLocale() : this.appLocale,
      myLanguage: myLanguage ?? this.myLanguage,
      partnerLanguages: partnerLanguages ?? this.partnerLanguages,
      pairA: pairA != null ? pairA() : this.pairA,
      pairB: pairB != null ? pairB() : this.pairB,
      micDenials: micDenials ?? this.micDenials,
    );
  }

  @override
  List<Object?> get props => [
    onboardingDone,
    appLocale,
    myLanguage,
    partnerLanguages,
    pairA,
    pairB,
    micDenials,
  ];
}

/// The app's shared preferences, opened at start-up.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => getIt<SharedPreferences>(),
);

/// User settings, read synchronously at start-up so routing can depend on them.
final userSettingsProvider =
    NotifierProvider<UserSettingsNotifier, UserSettings>(
      UserSettingsNotifier.new,
    );

/// Loads and saves [UserSettings] in shared preferences.
class UserSettingsNotifier extends Notifier<UserSettings> {
  static const _onboardingDone = 'onboarding_done';
  static const _appLocale = 'app_locale';
  static const _myLanguage = 'my_language';
  static const _partnerLanguages = 'partner_languages';
  static const _pairA = 'pair_a';
  static const _pairB = 'pair_b';
  static const _micDenials = 'mic_denials';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  UserSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return UserSettings(
      onboardingDone: prefs.getBool(_onboardingDone) ?? false,
      appLocale: prefs.getString(_appLocale),
      myLanguage: prefs.getString(_myLanguage),
      partnerLanguages: prefs.getStringList(_partnerLanguages) ?? const [],
      pairA: prefs.getString(_pairA),
      pairB: prefs.getString(_pairB),
      micDenials: prefs.getInt(_micDenials) ?? 0,
    );
  }

  /// Sets the app language; null follows the phone (AC-11.4, AC-11.5).
  Future<void> setAppLocale(String? locale) async {
    state = state.copyWith(appLocale: () => locale);
    await (locale == null
        ? _prefs.remove(_appLocale)
        : _prefs.setString(_appLocale, locale));
  }

  /// Saves the languages chosen in onboarding and resets the pair to them.
  Future<void> setLanguages({
    required String mine,
    required List<String> partners,
  }) async {
    state = state.copyWith(
      myLanguage: mine,
      partnerLanguages: partners,
      pairA: () => null,
      pairB: () => null,
    );
    await _prefs.setString(_myLanguage, mine);
    await _prefs.setStringList(_partnerLanguages, partners);
    await _prefs.remove(_pairA);
    await _prefs.remove(_pairB);
  }

  /// Sets the language pair used by the modes.
  Future<void> setPair(LanguagePair pair) async {
    state = state.copyWith(pairA: () => pair.a, pairB: () => pair.b);
    await _prefs.setString(_pairA, pair.a);
    await _prefs.setString(_pairB, pair.b);
  }

  /// Marks onboarding finished (true) or asks to run it again (false, AC-01.5).
  Future<void> setOnboardingDone(bool done) async {
    state = state.copyWith(onboardingDone: done);
    await _prefs.setBool(_onboardingDone, done);
  }

  /// Counts a refused microphone request (AC-01.7).
  Future<void> recordMicDenial() async {
    state = state.copyWith(micDenials: state.micDenials + 1);
    await _prefs.setInt(_micDenials, state.micDenials);
  }

  /// Clears refusals once the microphone is allowed.
  Future<void> clearMicDenials() async {
    if (state.micDenials == 0) {
      return;
    }
    state = state.copyWith(micDenials: 0);
    await _prefs.remove(_micDenials);
  }
}

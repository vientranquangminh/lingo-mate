import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/engines.dart';
import 'user_settings.dart';

/// Which engine Auto tries first (AC-10.2).
enum EnginePreference {
  auto,
  preferOffline,
  preferStandard;

  /// The order the selector tries the text engines in.
  List<EngineKind> get order => switch (this) {
    EnginePreference.preferOffline => const [
      EngineKind.offline,
      EngineKind.standard,
    ],
    _ => const [EngineKind.standard, EngineKind.offline],
  };
}

/// How fast translations are read aloud.
enum VoiceSpeed {
  slow(0.75),
  normal(1),
  fast(1.25);

  const VoiceSpeed(this.rate);

  final double rate;
}

/// How large captions and transcript lines are drawn.
enum CaptionSize {
  small(0.875),
  medium(1),
  large(1.25),
  extraLarge(1.5);

  const CaptionSize(this.scale);

  final double scale;
}

/// Translation, voice and privacy settings from Me (F-10).
class AppPreferences extends Equatable {
  const AppPreferences({
    this.engine = EnginePreference.auto,
    this.allowLive = true,
    this.voiceSpeed = VoiceSpeed.normal,
    this.captionSize = CaptionSize.medium,
    this.keepScreenOn = true,
    this.analytics = true,
    this.crashReports = true,
  });

  final EnginePreference engine;
  final bool allowLive;
  final VoiceSpeed voiceSpeed;
  final CaptionSize captionSize;
  final bool keepScreenOn;
  final bool analytics;
  final bool crashReports;

  /// Returns a copy with the given fields replaced.
  AppPreferences copyWith({
    EnginePreference? engine,
    bool? allowLive,
    VoiceSpeed? voiceSpeed,
    CaptionSize? captionSize,
    bool? keepScreenOn,
    bool? analytics,
    bool? crashReports,
  }) => AppPreferences(
    engine: engine ?? this.engine,
    allowLive: allowLive ?? this.allowLive,
    voiceSpeed: voiceSpeed ?? this.voiceSpeed,
    captionSize: captionSize ?? this.captionSize,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    analytics: analytics ?? this.analytics,
    crashReports: crashReports ?? this.crashReports,
  );

  @override
  List<Object?> get props => [
    engine,
    allowLive,
    voiceSpeed,
    captionSize,
    keepScreenOn,
    analytics,
    crashReports,
  ];
}

/// The user's translation, voice and privacy settings.
final appPreferencesProvider =
    NotifierProvider<AppPreferencesNotifier, AppPreferences>(
      AppPreferencesNotifier.new,
    );

/// Loads and saves [AppPreferences] in shared preferences.
class AppPreferencesNotifier extends Notifier<AppPreferences> {
  static const _engine = 'pref_engine';
  static const _allowLive = 'pref_allow_live';
  static const _voiceSpeed = 'pref_voice_speed';
  static const _captionSize = 'pref_caption_size';
  static const _keepScreenOn = 'pref_keep_screen_on';
  static const _analytics = 'pref_analytics';
  static const _crashReports = 'pref_crash_reports';

  @override
  AppPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.where((v) => v.name == prefs.getString(key)).firstOrNull ??
        fallback;
    return AppPreferences(
      engine: pick(EnginePreference.values, _engine, EnginePreference.auto),
      allowLive: prefs.getBool(_allowLive) ?? true,
      voiceSpeed: pick(VoiceSpeed.values, _voiceSpeed, VoiceSpeed.normal),
      captionSize: pick(CaptionSize.values, _captionSize, CaptionSize.medium),
      keepScreenOn: prefs.getBool(_keepScreenOn) ?? true,
      analytics: prefs.getBool(_analytics) ?? true,
      crashReports: prefs.getBool(_crashReports) ?? true,
    );
  }

  /// Sets which engine Auto tries first.
  Future<void> setEngine(EnginePreference value) async {
    state = state.copyWith(engine: value);
    await ref.read(sharedPreferencesProvider).setString(_engine, value.name);
  }

  /// Allows or forbids the Live engine.
  Future<void> setAllowLive(bool value) =>
      _setBool(_allowLive, value, state.copyWith(allowLive: value));

  /// Sets how fast translations are read aloud.
  Future<void> setVoiceSpeed(VoiceSpeed value) async {
    state = state.copyWith(voiceSpeed: value);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_voiceSpeed, value.name);
  }

  /// Sets the caption size.
  Future<void> setCaptionSize(CaptionSize value) async {
    state = state.copyWith(captionSize: value);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_captionSize, value.name);
  }

  /// Keeps the screen on during sessions, or lets it sleep.
  Future<void> setKeepScreenOn(bool value) =>
      _setBool(_keepScreenOn, value, state.copyWith(keepScreenOn: value));

  /// Turns usage analytics on or off (AC-10.4).
  Future<void> setAnalytics(bool value) =>
      _setBool(_analytics, value, state.copyWith(analytics: value));

  /// Turns crash reporting on or off.
  Future<void> setCrashReports(bool value) =>
      _setBool(_crashReports, value, state.copyWith(crashReports: value));

  /// Stores a flag and publishes [next].
  Future<void> _setBool(String key, bool value, AppPreferences next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setBool(key, value);
  }
}

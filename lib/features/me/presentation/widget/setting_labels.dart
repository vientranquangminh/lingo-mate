import '../../../../core/settings/app_preferences.dart';
import '../../../../generated/l10n.dart';

/// Display names of the translation and voice settings.
abstract final class SettingLabels {
  /// Returns the name of engine preference [value].
  static String engine(AppLocalizations l10n, EnginePreference value) =>
      switch (value) {
        EnginePreference.auto => l10n.settingsEngineAuto,
        EnginePreference.preferOffline => l10n.settingsEnginePreferOffline,
        EnginePreference.preferStandard => l10n.settingsEnginePreferStandard,
      };

  /// Returns what engine preference [value] does.
  static String engineBody(AppLocalizations l10n, EnginePreference value) =>
      switch (value) {
        EnginePreference.auto => l10n.settingsEngineAutoBody,
        EnginePreference.preferOffline => l10n.settingsEnginePreferOfflineBody,
        EnginePreference.preferStandard =>
          l10n.settingsEnginePreferStandardBody,
      };

  /// Returns the name of voice speed [value].
  static String voice(AppLocalizations l10n, VoiceSpeed value) =>
      switch (value) {
        VoiceSpeed.slow => l10n.settingsVoiceSlow,
        VoiceSpeed.normal => l10n.settingsVoiceNormal,
        VoiceSpeed.fast => l10n.settingsVoiceFast,
      };

  /// Returns the name of caption size [value].
  static String caption(AppLocalizations l10n, CaptionSize value) =>
      switch (value) {
        CaptionSize.small => l10n.settingsCaptionSmall,
        CaptionSize.medium => l10n.settingsCaptionMedium,
        CaptionSize.large => l10n.settingsCaptionLarge,
        CaptionSize.extraLarge => l10n.settingsCaptionExtraLarge,
      };
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/caption_scale.dart';
import '../../../../common/widgets/settings_row.dart';
import '../../../../common/widgets/settings_toggle_rows.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../core/settings/app_preferences.dart';
import '../widget/setting_labels.dart';

/// Translation & voice (S-17): engine preference, Live, voice speed, caption size and keep screen on (F-10).
class TranslationVoicePage extends ConsumerWidget {
  const TranslationVoicePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.meTranslationVoice)),
      body: ListView(
        padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
        children: [
          SettingsSectionHeader(l10n.settingsEngineSection),
          for (final option in EnginePreference.values)
            SettingsChoiceRow(
              label: SettingLabels.engine(l10n, option),
              description: SettingLabels.engineBody(l10n, option),
              selected: prefs.engine == option,
              onTap: () => notifier.setEngine(option),
            ),
          if (ref.watch(liveAvailableProvider))
            SettingsSwitchRow(
              label: l10n.settingsAllowLive,
              description: l10n.settingsAllowLiveBody,
              value: prefs.allowLive,
              onChanged: notifier.setAllowLive,
            ),
          SettingsSectionHeader(l10n.settingsVoiceSection),
          for (final speed in VoiceSpeed.values)
            SettingsChoiceRow(
              label: SettingLabels.voice(l10n, speed),
              selected: prefs.voiceSpeed == speed,
              onTap: () => notifier.setVoiceSpeed(speed),
            ),
          SettingsRow(
            icon: AppIcons.play,
            label: l10n.settingsVoiceSample,
            onTap: () => ref
                .read(speechSynthesizerProvider)
                .speak(
                  l10n.settingsVoiceSampleText,
                  lang: Localizations.localeOf(context).languageCode,
                ),
          ),
          SettingsRow(
            icon: AppIcons.download,
            label: l10n.settingsVoiceInstall,
            onTap: () => ref.read(systemSettingsProvider).installTtsVoice(),
          ),
          SettingsSectionHeader(l10n.settingsCaptionSection),
          for (final size in CaptionSize.values)
            SettingsChoiceRow(
              label: SettingLabels.caption(l10n, size),
              selected: prefs.captionSize == size,
              onTap: () => notifier.setCaptionSize(size),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing16.w,
              vertical: AppParams.spacing8.h,
            ),
            child: CaptionScale(
              child: Text(
                l10n.settingsCaptionPreview,
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          SizedBox(height: AppParams.spacing8.h),
          SettingsSwitchRow(
            label: l10n.settingsKeepScreenOn,
            description: l10n.settingsKeepScreenOnBody,
            value: prefs.keepScreenOn,
            onChanged: notifier.setKeepScreenOn,
          ),
        ],
      ),
    );
  }
}

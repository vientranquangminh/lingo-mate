import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_preferences.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_platform_slider.dart';
import 'caption_scale.dart';
import 'settings_toggle_rows.dart';

/// Shows the caption sheet: a caption size slider with a preview and the keep-screen-on switch, both saved at once (AC-03.3, AC-03.5).
Future<void> showCaptionSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppParams.radiusSheet.r),
        ),
      ),
      builder: (_) => const CaptionSettingsSheet(),
    );

/// The caption size and keep-screen-on controls of live caption screens.
class CaptionSettingsSheet extends ConsumerWidget {
  const CaptionSettingsSheet({super.key});

  /// Returns the label of [size].
  static String sizeLabel(BuildContext context, CaptionSize size) {
    final l10n = context.localization;
    return switch (size) {
      CaptionSize.small => l10n.settingsCaptionSmall,
      CaptionSize.medium => l10n.settingsCaptionMedium,
      CaptionSize.large => l10n.settingsCaptionLarge,
      CaptionSize.extraLarge => l10n.settingsCaptionExtraLarge,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final sizes = CaptionSize.values;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: AppParams.spacing16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsCaptionSection,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    sizeLabel(context, prefs.captionSize),
                    style: context.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppParams.spacing12.w),
              child: AppPlatformSlider(
                value: prefs.captionSize.index.toDouble(),
                max: (sizes.length - 1).toDouble(),
                divisions: sizes.length - 1,
                semanticLabel: l10n.settingsCaptionSection,
                onChanged: (value) =>
                    notifier.setCaptionSize(sizes[value.round()]),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
              child: CaptionScale(
                child: Text(
                  l10n.settingsCaptionPreview,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing16.h),
            SettingsSwitchRow(
              label: l10n.settingsKeepScreenOn,
              description: l10n.settingsKeepScreenOnBody,
              value: prefs.keepScreenOn,
              onChanged: notifier.setKeepScreenOn,
            ),
          ],
        ),
      ),
    );
  }
}

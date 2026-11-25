import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_dialog.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/settings_row.dart';
import '../../../../common/widgets/settings_toggle_rows.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../language_packs/data/notifier/language_packs_notifier.dart';
import '../../data/repository/data_eraser.dart';

/// Privacy & data (S-17): analytics and crash consent, Wi-Fi-only downloads, delete all data (F-10).
class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  /// Confirms twice, then deletes everything; the router returns to onboarding (AC-10.3).
  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final models = await showAppPlatformOptionDialog(
      context: context,
      title: l10n.privacyDeleteTitle,
      body: l10n.privacyDeleteBody,
      option: l10n.privacyDeleteModels,
      confirm: l10n.privacyDeleteContinue,
      cancel: l10n.commonCancel,
    );
    if (models == null || !context.mounted) {
      return;
    }
    final sure = await showAppPlatformDialog(
      context: context,
      title: l10n.privacyDeleteConfirmTitle,
      body: l10n.privacyDeleteConfirmBody,
      confirm: l10n.privacyDeleteConfirm,
      cancel: l10n.commonCancel,
      destructive: true,
    );
    if (sure != true) {
      return;
    }
    await ref.read(dataEraserProvider)(models: models);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final prefs = ref.watch(appPreferencesProvider);
    final notifier = ref.read(appPreferencesProvider.notifier);
    final wifiOnly = ref.watch(languagePacksProvider.select((s) => s.wifiOnly));
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.mePrivacy)),
      body: ListView(
        padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppParams.spacing16.w,
              AppParams.spacing16.h,
              AppParams.spacing16.w,
              AppParams.spacing8.h,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(AppIcons.privacy, color: scheme.primary),
                SizedBox(width: AppParams.spacing12.w),
                Expanded(
                  child: Text(
                    l10n.privacyIntro,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SettingsSwitchRow(
            label: l10n.privacyAnalytics,
            description: l10n.privacyAnalyticsBody,
            value: prefs.analytics,
            onChanged: notifier.setAnalytics,
          ),
          SettingsSwitchRow(
            label: l10n.privacyCrashReports,
            description: l10n.privacyCrashReportsBody,
            value: prefs.crashReports,
            onChanged: notifier.setCrashReports,
          ),
          SettingsSwitchRow(
            label: l10n.privacyWifiOnly,
            value: wifiOnly,
            onChanged: ref.read(languagePacksProvider.notifier).setWifiOnly,
          ),
          SizedBox(height: AppParams.spacing16.h),
          Divider(height: 1, color: scheme.outlineVariant),
          SettingsRow(
            icon: AppIcons.delete,
            label: l10n.privacyDeleteAll,
            destructive: true,
            onTap: () => _deleteAll(context, ref),
          ),
        ],
      ),
    );
  }
}

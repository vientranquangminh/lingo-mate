import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_language_button.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/settings_row.dart';
import '../../../../core/settings/user_settings.dart';
import '../../../../env.dart';
import '../../../../navigation/route_const.dart';

/// Me tab S-17 (P1 part): app language, offline packs, setup again; the rest of Settings joins with T-1.11.
class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(userSettingsProvider);
    final locale = settings.appLocale;
    final mine = settings.myLanguage;
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.meTitle)),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppParams.spacing16.w,
              AppParams.spacing16.h,
              AppParams.spacing16.w,
              AppParams.spacing4.h,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.meSettings.toUpperCase(),
                style: context.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SettingsRow(
            icon: AppIcons.language,
            label: l10n.appLanguage,
            value: locale == null
                ? l10n.appLanguagePhone
                : appLanguageEndonyms[locale] ?? locale,
            onTap: () => showAppLanguageSheet(context, ref),
          ),
          SettingsRow(
            icon: AppIcons.navTranslate,
            label: l10n.meMyLanguages,
            value: [
              if (mine != null) l10n.languageName(mine),
              ...settings.partnerLanguages.map(l10n.languageName),
            ].join(', '),
            onTap: () => _runSetup(ref),
          ),
          SettingsRow(
            icon: AppIcons.download,
            label: l10n.meOfflinePacks,
            onTap: () => context.pushNamed(AppRouteName.languagePacks),
          ),
          SettingsRow(
            icon: AppIcons.replay,
            label: l10n.meRunSetupAgain,
            onTap: () => _runSetup(ref),
          ),
          if (Env.devtoolsEnabled)
            SettingsRow(
              icon: AppIcons.settings,
              label: l10n.meDevtools,
              onTap: () => context.pushNamed(AppRouteName.devtools),
            ),
        ],
      ),
    );
  }

  /// Starts onboarding again; the router sends the user to Welcome (AC-01.5).
  static Future<void> _runSetup(WidgetRef ref) =>
      ref.read(userSettingsProvider.notifier).setOnboardingDone(false);
}

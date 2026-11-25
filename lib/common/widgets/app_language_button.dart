import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/user_settings.dart';
import '../../generated/l10n.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_action_sheet.dart';
import 'app_icon.dart';

/// Endonyms of the app's UI languages (F-11).
const appLanguageEndonyms = {'en': 'English', 'vi': 'Tiếng Việt'};

/// Opens the app language choices: phone language, then each UI language by its endonym (AC-11.4, AC-11.5).
Future<void> showAppLanguageSheet(BuildContext context, WidgetRef ref) {
  final l10n = context.localization;
  final settings = ref.read(userSettingsProvider.notifier);
  return showAppActionSheet(
    context: context,
    title: l10n.appLanguage,
    cancel: l10n.commonCancel,
    actions: [
      AppSheetAction(
        icon: AppIcons.language,
        label: l10n.appLanguagePhone,
        onSelected: () => settings.setAppLocale(null),
      ),
      for (final locale in AppLocalizations.supportedLocales)
        AppSheetAction(
          icon: AppIcons.language,
          label:
              appLanguageEndonyms[locale.languageCode] ?? locale.languageCode,
          onSelected: () => settings.setAppLocale(locale.languageCode),
        ),
    ],
  );
}

/// Pill showing the current app language with a globe; opens [showAppLanguageSheet].
class AppLanguageButton extends ConsumerWidget {
  const AppLanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final code = Localizations.localeOf(context).languageCode;
    final label = appLanguageEndonyms[code] ?? code;
    return Semantics(
      button: true,
      label: '${context.localization.appLanguage}: $label',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showAppLanguageSheet(context, ref),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppParams.spacing16.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(AppIcons.language, size: 20, color: scheme.onSurface),
                  SizedBox(width: AppParams.spacing8.w),
                  Text(
                    label,
                    style: context.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(width: AppParams.spacing4.w),
                  AppIcon(
                    AppIcons.chevronDown,
                    size: 18,
                    color: scheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

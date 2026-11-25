import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/quick_phrase_card.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/quick_phrases/quick_phrases.dart';
import '../../../../navigation/route_const.dart';
import 'situation_names.dart';

/// Quick phrases S-13: "Translate into", favourites and the situation grid (F-09).
class QuickTab extends ConsumerWidget {
  const QuickTab({super.key});

  /// Lets the user pick the language phrases are translated into.
  Future<void> _pickTarget(
    BuildContext context,
    WidgetRef ref,
    QuickPhraseCatalog catalog,
    String source,
  ) {
    final l10n = context.localization;
    final languages = catalog.languages.where((l) => l != source).toList()
      ..sort((a, b) => l10n.languageName(a).compareTo(l10n.languageName(b)));
    return showAppActionSheet(
      context: context,
      title: l10n.homePickLanguage,
      cancel: l10n.commonCancel,
      actions: [
        for (final code in languages)
          AppSheetAction(
            icon: AppIcons.language,
            label: l10n.languageName(code),
            onSelected: () =>
                ref.read(quickTargetProvider.notifier).select(code),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final catalog = ref.watch(quickPhraseCatalogProvider).value;
    final source = ref.watch(quickSourceProvider);
    final target = ref.watch(quickTargetProvider);
    if (catalog == null) {
      return const SizedBox.shrink();
    }
    final situations = catalog.situations;
    return ListView(
      padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppParams.spacing20.w),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppPlatformOutlinedButton(
              onPressed: () => _pickTarget(context, ref, catalog, source),
              text: l10n.quickTranslateInto(l10n.languageName(target)),
            ),
          ),
        ),
        SizedBox(height: AppParams.spacing16.h),
        QuickFavoritesRow(
          pair: LanguagePair(source, target),
          title: l10n.quickFavorites,
        ),
        SizedBox(height: AppParams.spacing16.h),
        for (var i = 0; i < situations.length; i += 2)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppParams.spacing20.w,
              0,
              AppParams.spacing20.w,
              AppParams.spacing12.h,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _SituationCard(situation: situations[i])),
                  SizedBox(width: AppParams.spacing12.w),
                  Expanded(
                    child: i + 1 < situations.length
                        ? _SituationCard(situation: situations[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One situation tile: icon, name and phrase count.
class _SituationCard extends StatelessWidget {
  const _SituationCard({required this.situation});

  final Situation situation;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final name = SituationNames.name(l10n, situation.key);
    final count = l10n.quickPhraseCount(situation.phrases.length);
    return Semantics(
      button: true,
      label: '$name, $count',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          onTap: () => context.pushNamed(
            AppRouteName.situation,
            pathParameters: {'key': situation.key},
          ),
          child: Padding(
            padding: EdgeInsets.all(AppParams.spacing16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  SituationNames.icon(situation.icon),
                  size: 28,
                  color: scheme.primary,
                ),
                SizedBox(height: AppParams.spacing12.h),
                Text(
                  name,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: AppParams.spacing4.h),
                Text(
                  count,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../core/config/feature_switches.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/quick_phrases/quick_phrases.dart';
import '../../../../navigation/route_const.dart';
import '../widget/quick_phrase_row.dart';
import '../widget/situation_names.dart';

/// Situation S-14: the phrases of one situation, own language first with the translation below (F-09).
class SituationPage extends ConsumerWidget {
  const SituationPage({super.key, required this.situationKey});

  final String situationKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final situation = ref
        .watch(quickPhraseCatalogProvider)
        .value
        ?.situation(situationKey);
    final pair = LanguagePair(
      ref.watch(quickSourceProvider),
      ref.watch(quickTargetProvider),
    );
    final starred =
        ref.watch(quickFavoriteKeysProvider(pair)).value ?? const [];
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(
        title: Text(SituationNames.name(l10n, situationKey)),
        trailingActions: [
          if (ref.watch(featureSwitchesProvider.select((s) => s.roleplay)))
            AppCircleIconButton(
              icon: AppIcons.modeConversation,
              semanticLabel: l10n.roleplayStart,
              borderColor: Colors.transparent,
              onPressed: () => context.pushNamed(
                AppRouteName.roleplay,
                pathParameters: {'key': situationKey},
                queryParameters: {'from': pair.a, 'to': pair.b},
              ),
            ),
        ],
      ),
      body: situation == null
          ? const SizedBox.shrink()
          : ListView.separated(
              padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
              itemCount: situation.phrases.length + 1,
              separatorBuilder: (_, i) => i == 0
                  ? const SizedBox.shrink()
                  : Divider(
                      height: 1,
                      indent: AppParams.spacing20.w,
                      endIndent: AppParams.spacing20.w,
                      color: scheme.outlineVariant,
                    ),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppParams.spacing20.w,
                      AppParams.spacing8.h,
                      AppParams.spacing20.w,
                      AppParams.spacing8.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.quickSubtitle(
                            l10n.languageName(pair.a),
                            l10n.languageName(pair.b),
                          ),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: AppParams.spacing4.h),
                        Text(
                          l10n.quickHint,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final phrase = situation.phrases[i - 1];
                return QuickPhraseRow(
                  key: ValueKey('${phrase.key}-${pair.a}-${pair.b}'),
                  phrase: phrase,
                  pair: pair,
                  starred: starred.contains(phrase.key),
                );
              },
            ),
    );
  }
}

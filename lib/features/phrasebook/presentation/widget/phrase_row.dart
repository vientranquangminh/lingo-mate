import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/phrases/phrase_repository.dart';

/// A phrasebook row: translation, original, tags and source, and a play button (doc 08 PhraseRow).
class PhraseRow extends ConsumerWidget {
  const PhraseRow({super.key, required this.item, required this.onTap});

  final PhraseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final phrase = item.phrase;
    final meta = [
      ...item.tags.map((t) => t.name),
      ?item.sessionTitle,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing20.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          phrase.targetText,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (phrase.favorite) ...[
                        SizedBox(width: AppParams.spacing4.w),
                        AppIcon(
                          AppIcons.starFilled,
                          size: 16,
                          color: scheme.primary,
                          semanticLabel: l10n.phraseFavorite,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppParams.spacing4.h),
                  Text(
                    phrase.sourceText,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    SizedBox(height: AppParams.spacing4.h),
                    Text(
                      meta,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: AppParams.spacing12.w),
            AppCircleIconButton(
              icon: AppIcons.speaker,
              semanticLabel: l10n.phrasesPlay(
                l10n.languageName(phrase.targetLang),
              ),
              color: scheme.primary,
              onPressed: () => ref
                  .read(speechSynthesizerProvider)
                  .speak(phrase.targetText, lang: phrase.targetLang),
            ),
          ],
        ),
      ),
    );
  }
}

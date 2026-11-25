import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engines/selection/engine_selector.dart';
import '../../core/quick_phrases/quick_phrases.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'speak_or_show.dart';

/// Card of a favourite quick phrase: translation above, own language below; tap speaks, long-press shows it large.
class QuickPhraseCard extends ConsumerWidget {
  const QuickPhraseCard({super.key, required this.phrase, required this.pair});

  final QuickPhrase phrase;
  final LanguagePair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final target = phrase.text(pair.b);
    final source = phrase.text(pair.a);
    return SizedBox(
      width: 168.w,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => speakOrShow(
            context,
            ref,
            text: target,
            lang: pair.b,
            original: source,
          ),
          onLongPress: () => openShowMode(
            context,
            text: target,
            original: source,
            lang: pair.b,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppParams.spacing12.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: AppParams.spacing4.h),
                Text(
                  source,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

/// Horizontal row of favourite quick phrase cards for [pair], hidden when there are none (AC-09.5).
class QuickFavoritesRow extends ConsumerWidget {
  const QuickFavoritesRow({
    super.key,
    required this.pair,
    required this.title,
    this.trailing,
    this.padding = AppParams.spacing20,
    this.bottomSpacing = 0,
  });

  final LanguagePair pair;
  final String title;
  final Widget? trailing;
  final double padding;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final catalog = ref.watch(quickPhraseCatalogProvider).value;
    final keys = ref.watch(quickFavoriteKeysProvider(pair)).value ?? const [];
    final phrases = [
      if (catalog != null)
        for (final key in keys) ?catalog.phrase(key),
    ];
    if (phrases.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding.w),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        SizedBox(height: AppParams.spacing8.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: padding.w),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, phrase) in phrases.indexed) ...[
                  if (i > 0) SizedBox(width: AppParams.spacing8.w),
                  QuickPhraseCard(phrase: phrase, pair: pair),
                ],
              ],
            ),
          ),
        ),
        SizedBox(height: bottomSpacing.h),
      ],
    );
  }
}

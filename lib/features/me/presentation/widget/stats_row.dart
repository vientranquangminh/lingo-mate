import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../data/notifier/me_stats_provider.dart';

/// Three tiles: hours translated, phrases saved, review streak (AC-13.7).
class StatsRow extends ConsumerWidget {
  const StatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final stats = ref.watch(meStatsProvider);
    final hours = stats.translatedSec / 3600;
    final hoursText = hours >= 10
        ? hours.round().toString()
        : hours.toStringAsFixed(1);
    final tiles = [
      _Tile(value: l10n.meStatHours(hoursText), label: l10n.meStatTranslated),
      _Tile(value: '${stats.phrasesSaved}', label: l10n.meStatPhrases),
      _Tile(value: l10n.meStatDays(stats.streakDays), label: l10n.meStatStreak),
    ];
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final tile in tiles) ...[
            tile,
            SizedBox(height: AppParams.spacing8.h),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) SizedBox(width: AppParams.spacing8.w),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// One stat: a big value and a label.
class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(AppParams.spacing12.r),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: context.textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

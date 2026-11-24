import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../core/audio/latency_timeline.dart';
import '../../data/notifier/devtools_notifier.dart';
import '../../data/notifier/devtools_providers.dart';

/// Overlay listing per-utterance stage timings when the devtools HUD is on.
class LatencyHud extends ConsumerWidget {
  const LatencyHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(
      devtoolsProvider.select((s) => s.latencyHudVisible),
    );
    final rows = ref.watch(latencyLogProvider);
    if (!visible || rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.localization;
    final labels = {
      LatencyStage.vadEnd.name: l10n.devtoolsStageVadEnd,
      LatencyStage.asrDone.name: l10n.devtoolsStageAsr,
      LatencyStage.translationShown.name: l10n.devtoolsStageTranslation,
      LatencyStage.playbackStart.name: l10n.devtoolsStagePlayback,
    };
    final style = context.textTheme.labelSmall?.copyWith(
      color: scheme.onInverseSurface,
    );
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: EdgeInsets.all(AppParams.spacing8.r),
            padding: EdgeInsets.all(AppParams.spacing8.r),
            decoration: BoxDecoration(
              color: scheme.inverseSurface,
              borderRadius: BorderRadius.circular(AppParams.radius4.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in rows)
                  Text(
                    row.entries
                        .map(
                          (e) =>
                              '${labels[e.key] ?? e.key} '
                              '${e.value ?? l10n.devtoolsNoValue}',
                        )
                        .join(' · '),
                    style: style,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

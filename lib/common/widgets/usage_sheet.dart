import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/quota/quota_engine.dart';
import '../../core/quota/quota_providers.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';

/// Shows the usage sheet S-18: Standard bars for the 5-hour window and the week with local reset times (AC-14.7).
Future<void> showUsageSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppParams.radiusSheet.r),
    ),
  ),
  builder: (_) => const UsageSheet(),
);

/// The usage bars.
class UsageSheet extends ConsumerWidget {
  const UsageSheet({super.key});

  /// "21/30 min" for minutes, "2.1/6 h" for hours.
  static String amount(BuildContext context, QuotaWindow window) {
    final l10n = context.localization;
    if (window.limitSec >= 2 * 3600) {
      String hours(int sec) {
        final h = sec / 3600;
        return h == h.roundToDouble() ? '${h.round()}' : h.toStringAsFixed(1);
      }

      return l10n.usageHours(hours(window.usedSec), hours(window.limitSec));
    }
    return l10n.usageMinutes(
      (window.usedSec / 60).ceil(),
      (window.limitSec / 60).round(),
    );
  }

  /// "resets 14:30" today, "resets Mon 09:12" on another day, "not started" with no window.
  static String reset(BuildContext context, QuotaWindow window, DateTime now) {
    final l10n = context.localization;
    final at = window.resetAt;
    if (at == null) {
      return l10n.usageNotStarted;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final time = sameDay
        ? DateFormat.Hm(locale).format(at)
        : '${DateFormat.E(locale).format(at)} ${DateFormat.Hm(locale).format(at)}';
    return l10n.usageResets(time);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(standardQuotaProvider).value;
    final now = DateTime.now();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppParams.spacing24.w,
          0,
          AppParams.spacing24.w,
          AppParams.spacing24.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.usageTitle,
              style: context.textTheme.titleLarge?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: AppParams.spacing16.h),
            Text(
              l10n.usageStandard,
              style: context.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            if (status != null) ...[
              UsageBar(
                label: l10n.usageWindow,
                detail:
                    '${amount(context, status.window)} · ${reset(context, status.window, now)}',
                fraction: status.window.fraction,
              ),
              UsageBar(
                label: l10n.usageWeek,
                detail:
                    '${amount(context, status.week)} · ${reset(context, status.week, now)}',
                fraction: status.week.fraction,
              ),
            ],
            SizedBox(height: AppParams.spacing12.h),
            Text(
              l10n.usageOfflineFree,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled bar with an amount and reset line.
class UsageBar extends StatelessWidget {
  const UsageBar({
    super.key,
    required this.label,
    required this.detail,
    required this.fraction,
  });

  final String label;
  final String detail;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final full = fraction >= 1;
    return Semantics(
      label: '$label, $detail',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(top: AppParams.spacing12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppParams.spacing4.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
              child: Container(
                height: AppParams.progressBarHeight.h,
                color: scheme.surfaceContainerHigh,
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: fraction.clamp(0, 1).toDouble(),
                  heightFactor: 1,
                  child: ColoredBox(
                    color: full ? scheme.error : scheme.primary,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing4.h),
            Text(
              detail,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

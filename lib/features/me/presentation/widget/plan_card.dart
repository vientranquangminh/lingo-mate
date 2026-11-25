import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/usage_sheet.dart';
import '../../../../core/quota/quota_providers.dart';

/// The plan card on Me: plan name and the Standard week bar; opens the usage sheet (AC-13.7).
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final status = ref.watch(standardQuotaProvider).value;
    final radius = BorderRadius.circular(AppParams.radiusCard.r);
    return Material(
      color: scheme.inverseSurface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => showUsageSheet(context),
        child: Padding(
          padding: EdgeInsets.all(AppParams.spacing16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.planFree,
                style: context.textTheme.titleMedium?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
              SizedBox(height: AppParams.spacing8.h),
              Text(
                l10n.planStandardWeek,
                style: context.textTheme.labelMedium?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
              if (status != null) ...[
                SizedBox(height: AppParams.spacing4.h),
                Text(
                  UsageSheet.amount(context, status.week),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: scheme.onInverseSurface,
                  ),
                ),
                SizedBox(height: AppParams.spacing8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
                  child: LinearProgressIndicator(
                    value: status.week.fraction,
                    minHeight: AppParams.progressBarHeight.h,
                    color: scheme.primaryContainer,
                    backgroundColor: scheme.onInverseSurface.withValues(
                      alpha: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

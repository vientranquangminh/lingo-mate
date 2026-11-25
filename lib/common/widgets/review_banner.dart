import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// Brand banner with the number of due review cards and the streak; opens Review (S-11, S-20).
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({
    super.key,
    required this.count,
    required this.label,
    required this.streak,
    required this.onTap,
  });

  final int count;
  final String label;
  final String? streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final streak = this.streak;
    final radius = BorderRadius.circular(AppParams.radiusCard.r);
    return Semantics(
      button: true,
      label: [('$count $label'), ?streak].join(', '),
      excludeSemantics: true,
      child: Material(
        color: scheme.primary,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing16.w,
              vertical: AppParams.spacing12.h,
            ),
            child: Row(
              children: [
                Text(
                  '$count',
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
                SizedBox(width: AppParams.spacing12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                      if (streak != null)
                        Text(
                          streak,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
                AppIcon(AppIcons.chevronRight, color: scheme.onPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

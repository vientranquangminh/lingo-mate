import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';
import 'app_motion.dart';

/// A calm empty or idle screen: an icon in a tinted circle, a message and an optional action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final AppIcons icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing32.w,
          vertical: AppParams.spacing24.h,
        ),
        child: AppFadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppParams.emptyStateCircle.r,
                height: AppParams.emptyStateCircle.r,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  icon,
                  size: AppParams.emptyStateIcon,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(height: AppParams.spacing20.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[
                SizedBox(height: AppParams.spacing16.h),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

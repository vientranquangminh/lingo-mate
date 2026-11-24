import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_colors.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';
import 'app_platform_text_button.dart';

/// How serious a banner is.
enum AppBannerKind { info, warning, error }

/// Inline message with an icon and an optional action (doc 08 Banner).
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.kind,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final AppBannerKind kind;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, tint) = switch (kind) {
      AppBannerKind.info => (AppIcons.info, scheme.primary),
      AppBannerKind.warning => (AppIcons.warning, context.appColors.warning),
      AppBannerKind.error => (AppIcons.error, scheme.error),
    };
    final action = actionLabel;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing16.w,
          vertical: AppParams.spacing12.h,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          border: Border.all(color: tint),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIcon(icon, size: 20, color: tint),
            SizedBox(width: AppParams.spacing12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  if (action != null && onAction != null)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: AppPlatformTextButton(
                        onPressed: onAction,
                        text: action,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

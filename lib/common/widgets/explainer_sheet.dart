import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';
import 'app_platform_elevated_button.dart';
import 'app_platform_text_button.dart';

/// Shows an explainer (doc 08 ExplainerSheet): icon, title, body, a primary and a secondary action. Returns true for primary.
Future<bool> showExplainerSheet({
  required BuildContext context,
  required AppIcons icon,
  required String title,
  required String body,
  required String primary,
  required String secondary,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppParams.radiusSheet.r),
      ),
    ),
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppParams.spacing24.w,
          AppParams.spacing32.h,
          AppParams.spacing24.w,
          AppParams.spacing16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72.r,
                height: 72.r,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    icon,
                    size: 32,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing20.h),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: sheetContext.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing12.h),
            Text(
              body,
              textAlign: TextAlign.center,
              style: sheetContext.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppParams.spacing24.h),
            AppPlatformElevatedButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              text: primary,
            ),
            SizedBox(height: AppParams.spacing8.h),
            AppPlatformTextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              text: secondary,
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

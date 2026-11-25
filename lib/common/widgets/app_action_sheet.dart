import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// One choice in an action sheet.
class AppSheetAction {
  const AppSheetAction({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final AppIcons icon;
  final String label;
  final VoidCallback onSelected;
}

/// Shows a list of actions from the bottom; runs the chosen one after the sheet closes.
Future<void> showAppActionSheet({
  required BuildContext context,
  required String title,
  required List<AppSheetAction> actions,
  required String cancel,
}) async {
  AppSheetAction? chosen;
  if (context.isCupertino) {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(title),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              onPressed: () {
                chosen = action;
                Navigator.of(sheetContext).pop();
              },
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancel),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppParams.radiusSheet.r),
        ),
      ),
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppParams.spacing24.w,
                  ),
                  child: Text(
                    title,
                    style: sheetContext.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(height: AppParams.spacing8.h),
                for (final action in actions)
                  InkWell(
                    onTap: () {
                      chosen = action;
                      Navigator.of(sheetContext).pop();
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: AppParams.buttonHeight.h,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppParams.spacing24.w,
                          vertical: AppParams.spacing12.h,
                        ),
                        child: Row(
                          children: [
                            AppIcon(action.icon, color: scheme.onSurface),
                            SizedBox(width: AppParams.spacing16.w),
                            Expanded(
                              child: Text(
                                action.label,
                                style: sheetContext.textTheme.bodyLarge
                                    ?.copyWith(color: scheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: AppParams.spacing8.h),
              ],
            ),
          ),
        );
      },
    );
  }
  chosen?.onSelected();
}

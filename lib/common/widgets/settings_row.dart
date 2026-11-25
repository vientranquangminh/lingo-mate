import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// A settings line: icon, label, optional value and chevron; at least 48 dp tall (doc 08 SettingsRow).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.destructive = false,
  });

  final AppIcons icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    final value = this.value;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing16.w,
              vertical: AppParams.spacing12.h,
            ),
            child: Row(
              children: [
                AppIcon(icon, color: color),
                SizedBox(width: AppParams.spacing16.w),
                Expanded(
                  child: Text(
                    label,
                    style: context.textTheme.bodyLarge?.copyWith(color: color),
                  ),
                ),
                if (value != null) ...[
                  SizedBox(width: AppParams.spacing8.w),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (!destructive) ...[
                  SizedBox(width: AppParams.spacing8.w),
                  AppIcon(
                    AppIcons.chevronRight,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

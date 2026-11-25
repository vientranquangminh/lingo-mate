import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';
import 'app_platform_switch.dart';

/// A settings line with a label, optional description and an on/off switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: [label, ?description].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: _RowBody(
          label: label,
          description: description,
          trailing: AppPlatformSwitch(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

/// One option of a single-choice settings list, checked when [selected].
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: [label, ?description].join('. '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: _RowBody(
          label: label,
          description: description,
          trailing: SizedBox.square(
            dimension: 24.r,
            child: selected
                ? AppIcon(AppIcons.check, color: scheme.primary)
                : null,
          ),
        ),
      ),
    );
  }
}

/// Label and description on the left, [trailing] on the right, at least 48 dp tall.
class _RowBody extends StatelessWidget {
  const _RowBody({
    required this.label,
    required this.description,
    required this.trailing,
  });

  final String label;
  final String? description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = this.description;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing16.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  if (description != null) ...[
                    SizedBox(height: AppParams.spacing4.h),
                    Text(
                      description,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: AppParams.spacing12.w),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Small upper-case heading above a group of settings rows.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppParams.spacing16.w,
        AppParams.spacing24.h,
        AppParams.spacing16.w,
        AppParams.spacing4.h,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: context.textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

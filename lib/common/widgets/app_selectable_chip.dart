import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// Pill that toggles on tap, showing a check when selected, with optional trailing badges.
class AppSelectableChip extends StatelessWidget {
  const AppSelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.badges = const [],
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: [label, ...badges].join(', '),
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerLowest,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => onChanged(!selected),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppParams.spacing16.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    AppIcon(AppIcons.check, size: 18, color: foreground),
                    SizedBox(width: AppParams.spacing4.w),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: context.textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                  for (final badge in badges) ...[
                    SizedBox(width: AppParams.spacing8.w),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppParams.radiusChip.r,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppParams.spacing8.w,
                          vertical: 2.h,
                        ),
                        child: Text(
                          badge,
                          style: context.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

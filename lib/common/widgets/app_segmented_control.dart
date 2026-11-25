import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';

/// Two or more mutually exclusive segments, e.g. `Quick | Mine`.
class AppSegmentedControl<T extends Object> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        onValueChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
        children: {
          for (final entry in segments.entries)
            entry.key: Padding(
              padding: EdgeInsets.symmetric(vertical: AppParams.spacing8.h),
              child: Text(entry.value),
            ),
        },
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppParams.spacing4.r),
        child: Row(
          children: [
            for (final entry in segments.entries)
              Expanded(
                child: Semantics(
                  selected: entry.key == selected,
                  button: true,
                  child: Material(
                    color: entry.key == selected
                        ? scheme.surfaceContainerLowest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AppParams.radiusCard.r - AppParams.spacing4.r,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        AppParams.radiusCard.r - AppParams.spacing4.r,
                      ),
                      onTap: () => onChanged(entry.key),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: AppParams.buttonHeight.h,
                        ),
                        child: Center(
                          child: Text(
                            entry.value,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: entry.key == selected
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

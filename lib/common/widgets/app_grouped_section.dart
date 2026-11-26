import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../resources/app_params.dart';

/// Rows grouped in one rounded card with hairline dividers between them, as in the settings lists.
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({super.key, required this.children, this.margin});

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          margin ?? EdgeInsets.symmetric(horizontal: AppParams.spacing16.w),
      child: Material(
        color: scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: AppParams.spacing48.w,
                  color: scheme.outlineVariant,
                ),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

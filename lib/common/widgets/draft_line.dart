import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';

/// The words heard so far in the utterance still being spoken, shown before its translation arrives.
class DraftLine extends StatelessWidget {
  const DraftLine({super.key, required this.text, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(
              horizontal: AppParams.spacing20.w,
              vertical: AppParams.spacing12.h,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.localization.draftHearing,
              style: context.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
            SizedBox(height: AppParams.spacing4.h),
            Text(
              text,
              style: context.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

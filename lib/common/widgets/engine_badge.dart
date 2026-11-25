import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engines/engines.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_colors.dart';
import '../resources/app_params.dart';

/// Small pill in an engine's colours, e.g. "Standard · 36 min" or "Offline (fallback)".
class EngineBadge extends StatelessWidget {
  const EngineBadge({super.key, required this.engine, required this.label});

  final EngineKind engine;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors.engine(engine);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing12.w,
          vertical: AppParams.spacing4.h,
        ),
        child: Text(
          label,
          style: context.textTheme.labelLarge?.copyWith(
            color: colors.foreground,
          ),
        ),
      ),
    );
  }
}

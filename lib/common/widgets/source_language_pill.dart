import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// The `JA ▾ → VI` pill: the speaker's language, which opens the picker, and the user's language.
class SourceLanguagePill extends StatelessWidget {
  const SourceLanguagePill({
    super.key,
    required this.source,
    required this.target,
    required this.semanticLabel,
    required this.onTap,
  });

  final String source;
  final String target;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = context.textTheme.labelLarge?.copyWith(
      color: scheme.onSurface,
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: AppParams.pillPadding.r,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(source, style: style),
                AppIcon(
                  AppIcons.chevronDown,
                  size: 16,
                  color: scheme.onSurface,
                ),
                SizedBox(width: AppParams.spacing4.w),
                AppIcon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(width: AppParams.spacing4.w),
                Text(target, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

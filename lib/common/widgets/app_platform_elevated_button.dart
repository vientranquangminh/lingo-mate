import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';
import 'app_circular_progress_indicator.dart';

/// Full-width filled button with an optional leading icon, border and loading state.
class AppPlatformElevatedButton extends StatelessWidget {
  const AppPlatformElevatedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.loading = false,
    this.color,
    this.textColor,
    this.borderColor,
    this.height,
    this.borderRadius,
  });

  final VoidCallback? onPressed;
  final String text;
  final Widget? icon;
  final bool loading;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final double? height;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = color ?? scheme.primary;
    final foreground = textColor ?? scheme.onPrimary;
    final radius = BorderRadius.circular(borderRadius ?? AppParams.radius24.r);
    final leading = loading
        ? SizedBox.square(
            dimension: 20.r,
            child: AppCircularProgressIndicator(color: foreground),
          )
        : icon;

    final onPressed = loading ? null : this.onPressed;
    final padding = EdgeInsets.symmetric(horizontal: 16.w);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading, SizedBox(width: 8.w)],
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: foreground),
          ),
        ),
      ],
    );
    final Widget button = context.isCupertino
        ? CupertinoButton(
            onPressed: onPressed,
            color: background,
            padding: padding,
            borderRadius: radius,
            disabledColor: background.withValues(alpha: 0.5),
            child: label,
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              disabledBackgroundColor: background.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: radius),
            ),
            child: label,
          );
    final borderColor = this.borderColor;

    return SizedBox(
      height: height ?? AppParams.buttonHeight.h,
      width: double.infinity,
      child: borderColor == null
          ? button
          : DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: radius,
                  side: BorderSide(color: borderColor),
                ),
              ),
              child: button,
            ),
    );
  }
}

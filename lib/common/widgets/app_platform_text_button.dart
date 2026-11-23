import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../extensions/platform_ext.dart';

/// Borderless text button with an optional leading icon.
class AppPlatformTextButton extends StatelessWidget {
  const AppPlatformTextButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.icon,
    this.color,
    this.disabledColor,
    this.textStyle,
  });

  final VoidCallback? onPressed;
  final String text;
  final IconData? icon;
  final Color? color;
  final Color? disabledColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.primary;
    final disabled = disabledColor ?? Theme.of(context).disabledColor;
    final style = (textStyle ?? Theme.of(context).textTheme.labelLarge)
        ?.copyWith(color: onPressed == null ? disabled : foreground);

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20.r, color: style?.color),
          SizedBox(width: 6.w),
        ],
        Text(text, style: style),
      ],
    );
    if (context.isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        minimumSize: Size.zero,
        disabledColor: Colors.transparent,
        child: label,
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        disabledForegroundColor: disabled,
      ),
      child: label,
    );
  }
}

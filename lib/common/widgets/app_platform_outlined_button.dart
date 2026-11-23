import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';

/// Pill-shaped outlined button with an optional leading label.
class AppPlatformOutlinedButton extends StatelessWidget {
  const AppPlatformOutlinedButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.leading,
    this.leadingIcon,
    this.foregroundColor,
    this.borderColor,
    this.backgroundColor,
    this.borderWidth = 1,
    this.padding = AppParams.pillPadding,
    this.fontSize = 14,
  });

  final VoidCallback? onPressed;
  final String text;
  final String? leading;
  final IconData? leadingIcon;
  final Color? foregroundColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final double borderWidth;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? scheme.primary;
    final border = borderColor ?? scheme.outline;
    final padding = this.padding.r;
    final style = TextStyle(fontSize: fontSize.sp, color: foreground);
    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: (fontSize + 2).r, color: foreground),
          SizedBox(width: 6.w),
        ],
        if (leading != null) ...[
          Text(leading!, style: style),
          SizedBox(width: 6.w),
        ],
        Text(text, style: style),
      ],
    );

    final shape = StadiumBorder(
      side: BorderSide(color: border, width: borderWidth),
    );
    if (context.isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: backgroundColor, shape: shape),
          child: Padding(padding: padding, child: label),
        ),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: backgroundColor,
        padding: padding,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: shape,
      ),
      child: label,
    );
  }
}

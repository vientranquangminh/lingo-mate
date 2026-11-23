import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../extensions/platform_ext.dart';

/// Icon-only button with a Material tooltip.
class AppPlatformIconButton extends StatelessWidget {
  const AppPlatformIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
    this.size = 24,
    this.compact = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? color;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: size.r, color: color);
    if (context.isCupertino) {
      return CupertinoButton(
        onPressed: onPressed,
        minimumSize: Size.zero,
        child: iconWidget,
      );
    }
    return IconButton(
      onPressed: onPressed,
      icon: iconWidget,
      color: color,
      tooltip: tooltip,
      iconSize: size.r,
      visualDensity: compact ? VisualDensity.compact : null,
    );
  }
}

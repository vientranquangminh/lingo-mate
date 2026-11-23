import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';

/// Platform app bar that can be used as a scaffold's `appBar`.
class AppPlatformAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPlatformAppBar({
    super.key,
    this.title,
    this.leading,
    this.trailingActions,
    this.backgroundColor,
    this.foregroundColor,
    this.toolbarHeight = kToolbarHeight,
    this.titleSpacing,
    this.bottom,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? trailingActions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double toolbarHeight;
  final double? titleSpacing;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return AppBar(
        title: title,
        leading: leading,
        actions: trailingActions,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        toolbarHeight: toolbarHeight,
        titleSpacing: titleSpacing,
        bottom: bottom,
      );
    }
    final actions = trailingActions;
    return CupertinoNavigationBar(
      middle: title,
      leading: leading,
      trailing: actions == null || actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
      backgroundColor: backgroundColor,
      bottom: bottom,
    );
  }
}

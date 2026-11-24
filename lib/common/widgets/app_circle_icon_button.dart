import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../resources/app_params.dart';
import 'app_icon.dart';

/// Round outlined button holding one [AppIcon], at least 48 dp.
class AppCircleIconButton extends StatelessWidget {
  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color,
    this.borderColor,
    this.selected = false,
    this.size = AppParams.buttonHeight,
  });

  final AppIcons icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? borderColor;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? scheme.onSurface;
    return Semantics(
      button: true,
      toggled: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: borderColor ?? scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size.r,
            child: Center(child: AppIcon(icon, color: tint)),
          ),
        ),
      ),
    );
  }
}

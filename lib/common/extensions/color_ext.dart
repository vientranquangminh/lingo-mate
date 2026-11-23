import 'package:material_ui/material_ui.dart';

extension ColorExtension on Color? {
  ColorFilter? get svgColor {
    return this == null ? null : ColorFilter.mode(this!, BlendMode.srcIn);
  }
}

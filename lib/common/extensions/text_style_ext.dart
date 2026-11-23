import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../gen/colors.gen.dart';
import '../resources/dimens.dart';
import 'platform_ext.dart';

extension PlatFormThemeDataExtension on BuildContext {
  TextStyle? get regularSize14BlackText => _style(
    material: (data) => data.textTheme.bodyMedium?.copyWith(
      color: ColorName.black,
      fontSize: Dimens.fontSize14.sp,
      fontWeight: FontWeight.w400,
    ),
    cupertino: (data) => data.textTheme.textStyle.copyWith(
      color: ColorName.black,
      fontSize: Dimens.fontSize14.sp,
      fontWeight: FontWeight.w400,
    ),
  );

  /// Builds a text style from the Cupertino or the Material theme.
  TextStyle? _style({
    required TextStyle? Function(ThemeData data) material,
    required TextStyle Function(CupertinoThemeData data) cupertino,
  }) => isCupertino
      ? cupertino(CupertinoTheme.of(this))
      : material(Theme.of(this));
}

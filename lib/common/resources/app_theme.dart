import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../gen/colors.gen.dart';

/// Material and Cupertino themes of the app.
class AppTheme {
  AppTheme._();

  static const _seedColor = ColorName.blueSeljuk;

  /// Returns the colour scheme for [brightness].
  static ColorScheme colorScheme(Brightness brightness) =>
      ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);

  /// Returns the Material theme for [brightness].
  static ThemeData materialTheme(Brightness brightness) =>
      ThemeData(colorScheme: colorScheme(brightness));

  /// Returns the Cupertino theme for [brightness].
  static CupertinoThemeData cupertinoTheme(Brightness brightness) {
    final scheme = colorScheme(brightness);
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}

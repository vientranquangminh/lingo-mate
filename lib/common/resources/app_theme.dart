import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../gen/colors.gen.dart';
import 'app_colors.dart';

/// Material and Cupertino themes of the app, built from the doc 08 §2.1 tokens.
class AppTheme {
  AppTheme._();

  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: ColorName.cyanMermaidHarbour,
    onPrimary: ColorName.white,
    primaryContainer: ColorName.cyanWaterslide,
    onPrimaryContainer: ColorName.cyanMermaidHarbour,
    secondary: ColorName.cyanMermaidHarbour,
    onSecondary: ColorName.white,
    secondaryContainer: ColorName.cyanWaterslide,
    onSecondaryContainer: ColorName.cyanMermaidHarbour,
    tertiary: ColorName.redMadder,
    onTertiary: ColorName.white,
    tertiaryContainer: ColorName.redVanillaStrawberry,
    onTertiaryContainer: ColorName.redMadder,
    error: ColorName.redInferno,
    onError: ColorName.white,
    surface: ColorName.orangeUnbleached,
    onSurface: ColorName.blueKuroiBlack,
    onSurfaceVariant: ColorName.blueMysteriousNight,
    surfaceContainerLowest: ColorName.white,
    surfaceContainerLow: ColorName.white,
    surfaceContainer: ColorName.white,
    surfaceContainerHigh: ColorName.orangeCowsMilk,
    surfaceContainerHighest: ColorName.orangeCowsMilk,
    outline: ColorName.orangeAragonite,
    outlineVariant: ColorName.orangeAragonite,
    inverseSurface: ColorName.blueKuroiBlack,
    onInverseSurface: ColorName.orangeBitOfSugar,
    inversePrimary: ColorName.cyanExquisiteTurquoise,
    shadow: ColorName.blueKuroiBlack,
    scrim: ColorName.blackA54,
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: ColorName.cyanExquisiteTurquoise,
    onPrimary: ColorName.cyanStellarExplorer,
    primaryContainer: ColorName.cyanBotanicalNight,
    onPrimaryContainer: ColorName.cyanExquisiteTurquoise,
    secondary: ColorName.cyanExquisiteTurquoise,
    onSecondary: ColorName.cyanStellarExplorer,
    secondaryContainer: ColorName.cyanBotanicalNight,
    onSecondaryContainer: ColorName.cyanExquisiteTurquoise,
    tertiary: ColorName.redForbiddenFruit,
    onTertiary: ColorName.redRustic,
    tertiaryContainer: ColorName.redRustic,
    onTertiaryContainer: ColorName.redForbiddenFruit,
    error: ColorName.redGeorgiaPeach,
    onError: ColorName.blueMidnightOil,
    surface: ColorName.blueMidnightOil,
    onSurface: ColorName.orangeBitOfSugar,
    onSurfaceVariant: ColorName.blueJacarandaLight,
    surfaceContainerLowest: ColorName.blueCoarseWool,
    surfaceContainerLow: ColorName.blueCoarseWool,
    surfaceContainer: ColorName.blueCoarseWool,
    surfaceContainerHigh: ColorName.blueMoonlessMystery,
    surfaceContainerHighest: ColorName.blueMoonlessMystery,
    outline: ColorName.blueCoal,
    outlineVariant: ColorName.blueCoal,
    inverseSurface: ColorName.orangeBitOfSugar,
    onInverseSurface: ColorName.blueKuroiBlack,
    inversePrimary: ColorName.cyanMermaidHarbour,
    shadow: ColorName.black,
    scrim: ColorName.blackA54,
  );

  /// Returns the colour scheme for [brightness].
  static ColorScheme colorScheme(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  /// Returns the extra colour roles for [brightness].
  static AppColors appColors(Brightness brightness) =>
      brightness == Brightness.dark ? AppColors.dark : AppColors.light;

  /// Returns the Material theme for [brightness].
  static ThemeData materialTheme(Brightness brightness) {
    final scheme = colorScheme(brightness);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: scheme.outlineVariant,
      extensions: [appColors(brightness)],
    );
  }

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

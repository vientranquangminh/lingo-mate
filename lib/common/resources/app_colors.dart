import 'package:material_ui/material_ui.dart';

import '../../gen/colors.gen.dart';

/// Foreground and background of one engine chip, plus its on-air dot.
@immutable
class EngineChipColors {
  const EngineChipColors({
    required this.foreground,
    required this.background,
    Color? dot,
  }) : dot = dot ?? foreground;

  final Color foreground;
  final Color background;
  final Color dot;
}

/// Colour roles of doc 08 §2.1 that the Material colour scheme has no slot for.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.engineOffline,
    required this.engineStandard,
    required this.engineLive,
    required this.success,
    required this.warning,
    required this.listening,
    required this.billingIssueBackground,
    required this.billingIssueForeground,
  });

  static const light = AppColors(
    engineOffline: EngineChipColors(
      foreground: ColorName.blueInkjet,
      background: ColorName.blueGhostlyTuna,
    ),
    engineStandard: EngineChipColors(
      foreground: ColorName.cyanMermaidHarbour,
      background: ColorName.cyanWaterslide,
    ),
    engineLive: EngineChipColors(
      foreground: ColorName.redMadder,
      background: ColorName.redVanillaStrawberry,
      dot: ColorName.redXMarksTheSpot,
    ),
    success: ColorName.greenWarpstoneGlow,
    warning: ColorName.orangeBloodhound,
    listening: ColorName.cyanMermaidHarbour,
    billingIssueBackground: ColorName.yellowSilentIvory,
    billingIssueForeground: ColorName.orangeBeerGlazedBacon,
  );

  static const dark = AppColors(
    engineOffline: EngineChipColors(
      foreground: ColorName.blueEphemeral,
      background: ColorName.blueDressBlues,
    ),
    engineStandard: EngineChipColors(
      foreground: ColorName.cyanExquisiteTurquoise,
      background: ColorName.cyanBotanicalNight,
    ),
    engineLive: EngineChipColors(
      foreground: ColorName.redForbiddenFruit,
      background: ColorName.redRustic,
    ),
    success: ColorName.greenShivering,
    warning: ColorName.orangeNotYoCheese,
    listening: ColorName.cyanExquisiteTurquoise,
    billingIssueBackground: ColorName.yellowSilentIvory,
    billingIssueForeground: ColorName.orangeBeerGlazedBacon,
  );

  final EngineChipColors engineOffline;
  final EngineChipColors engineStandard;
  final EngineChipColors engineLive;
  final Color success;
  final Color warning;
  final Color listening;
  final Color billingIssueBackground;
  final Color billingIssueForeground;

  @override
  AppColors copyWith({
    EngineChipColors? engineOffline,
    EngineChipColors? engineStandard,
    EngineChipColors? engineLive,
    Color? success,
    Color? warning,
    Color? listening,
    Color? billingIssueBackground,
    Color? billingIssueForeground,
  }) {
    return AppColors(
      engineOffline: engineOffline ?? this.engineOffline,
      engineStandard: engineStandard ?? this.engineStandard,
      engineLive: engineLive ?? this.engineLive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      listening: listening ?? this.listening,
      billingIssueBackground:
          billingIssueBackground ?? this.billingIssueBackground,
      billingIssueForeground:
          billingIssueForeground ?? this.billingIssueForeground,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// Reads [AppColors] from the theme.
extension AppColorsContext on BuildContext {
  /// The app's extra colour roles for the current brightness.
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

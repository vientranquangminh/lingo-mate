import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_colors.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/common/resources/app_theme.dart';
import 'package:lingo_mate/common/widgets/app_icon.dart';
import 'package:lingo_mate/common/widgets/engine_chip.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Pumps [chip] in the app theme with English strings.
  Future<void> pump(
    WidgetTester tester,
    Widget chip, {
    bool reduceMotion = false,
    Brightness brightness = Brightness.light,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.materialTheme(brightness),
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        ScreenUtil.init(context, designSize: AppConfiguration.mainAppSize);
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        );
      },
      home: Scaffold(body: Center(child: chip)),
    ),
  );

  testWidgets('shows each engine with its label, icon and colours', (
    tester,
  ) async {
    for (final (engine, label, icon, colors) in [
      (
        EngineKind.offline,
        'Offline',
        AppIcons.engineOffline,
        AppColors.light.engineOffline,
      ),
      (
        EngineKind.standard,
        'Standard',
        AppIcons.engineStandard,
        AppColors.light.engineStandard,
      ),
      (
        EngineKind.live,
        'Live',
        AppIcons.engineLive,
        AppColors.light.engineLive,
      ),
    ]) {
      await pump(tester, EngineChip(engine: engine));

      expect(find.text(label), findsOneWidget);
      final appIcon = tester.widget<AppIcon>(find.byType(AppIcon));
      expect(appIcon.icon, icon);
      expect(appIcon.color, colors.foreground);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(EngineChip),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, colors.background);
    }
  });

  testWidgets('shows Unavailable when no engine can run', (tester) async {
    await pump(tester, const EngineChip(engine: null));

    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      tester.widget<AppIcon>(find.byType(AppIcon)).icon,
      AppIcons.engineUnavailable,
    );
  });

  testWidgets('only Live has the on-air dot, which pulses', (tester) async {
    await pump(tester, const EngineChip(engine: EngineKind.standard));
    expect(
      find.descendant(
        of: find.byType(EngineChip),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );

    await pump(tester, const EngineChip(engine: EngineKind.live));
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(EngineChip),
        matching: find.byType(FadeTransition),
      ),
    );
    final start = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(fade.opacity.value, isNot(start));
  });

  testWidgets('the dot stays still when motion is reduced', (tester) async {
    await pump(
      tester,
      const EngineChip(engine: EngineKind.live),
      reduceMotion: true,
    );
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(EngineChip),
        matching: find.byType(FadeTransition),
      ),
    );
    final start = fade.opacity.value;

    await tester.pump(const Duration(milliseconds: 500));

    expect(fade.opacity.value, start);
    expect(start, 1);
  });

  testWidgets('announces the engine and opens the sheet on tap', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      EngineChip(engine: EngineKind.offline, onTap: () => taps++),
    );

    expect(
      find.bySemanticsLabel('Translation engine: Offline. Tap to change.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(EngineChip));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(EngineChip)).height,
      greaterThanOrEqualTo(48.h),
    );
  });
}

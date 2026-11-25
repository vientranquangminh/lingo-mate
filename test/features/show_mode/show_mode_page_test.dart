import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/features/show_mode/presentation/view/show_mode_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('shows the line large and turns it around', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          ScreenUtil.init(context, designSize: AppConfiguration.mainAppSize);
          return child!;
        },
        home: const ShowModePage(
          text: 'A table for two, please.',
          original: 'Cho tôi bàn hai người.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A table for two, please.'), findsOneWidget);
    expect(find.text('Cho tôi bàn hai người.'), findsOneWidget);
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 0);

    await tester.tap(find.bySemanticsLabel('Turn the text around'));
    await tester.pump();

    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 2);
  });

  testWidgets('greets the reader in the line\'s language (AC-11.8)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          ScreenUtil.init(context, designSize: AppConfiguration.mainAppSize);
          return child!;
        },
        home: const ShowModePage(text: 'Merci beaucoup', lang: 'fr'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Traduit pour vous'), findsOneWidget);
    expect(find.bySemanticsLabel('Phát'), findsOneWidget);
  });
}

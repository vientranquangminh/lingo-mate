import 'dart:io';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/common/widgets/app_icon.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('every icon has an SVG and every SVG has an icon', () {
    final files = Directory('assets/icons')
        .listSync()
        .map((e) => e.uri.pathSegments.last)
        .where((n) => n.endsWith('.svg'))
        .toSet();

    expect(AppIcons.values.map((i) => i.asset.split('/').last).toSet(), files);
    expect(files, hasLength(79));
  });

  test('every SVG draws with currentColor so it can be tinted', () {
    for (final icon in AppIcons.values) {
      final svg = File(icon.asset).readAsStringSync();
      expect(svg, contains('currentColor'), reason: icon.asset);
      expect(svg, contains('viewBox="0 0 24 24"'), reason: icon.asset);
    }
  });

  /// Pumps [child] with screen scaling.
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      builder: (context, c) {
        ScreenUtil.init(context, designSize: AppConfiguration.mainAppSize);
        return c!;
      },
      home: Center(child: child),
    ),
  );

  testWidgets('tints the icon and labels it for TalkBack', (tester) async {
    await pump(
      tester,
      const AppIcon(
        AppIcons.mic,
        color: Colors.transparent,
        semanticLabel: 'Speak',
      ),
    );

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      picture.colorFilter,
      const ColorFilter.mode(Colors.transparent, BlendMode.srcIn),
    );
    expect(find.bySemanticsLabel('Speak'), findsOneWidget);
  });

  testWidgets('hides decorative icons from accessibility', (tester) async {
    await pump(tester, const AppIcon(AppIcons.check));

    expect(
      find.descendant(
        of: find.byType(AppIcon),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });
}

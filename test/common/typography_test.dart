import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/common/resources/app_theme.dart';
import 'package:lingo_mate/gen/fonts.gen.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both themes use Be Vietnam Pro', () {
    for (final brightness in Brightness.values) {
      final material = AppTheme.materialTheme(brightness).textTheme;
      expect(material.bodyLarge?.fontFamily, FontFamily.beVietnamPro);
      expect(material.titleLarge?.fontFamily, FontFamily.beVietnamPro);
      expect(
        AppTheme.cupertinoTheme(brightness).textTheme.textStyle.fontFamily,
        FontFamily.beVietnamPro,
      );
    }
  });

  test('the text theme keeps the Material 3 sizes and line heights', () {
    final t = AppTheme.materialTheme(Brightness.light).textTheme;
    final expected = <String, (TextStyle?, double, double)>{
      'displaySmall': (t.displaySmall, 36, 44),
      'headlineMedium': (t.headlineMedium, 28, 36),
      'titleLarge': (t.titleLarge, 22, 28),
      'titleMedium': (t.titleMedium, 16, 24),
      'bodyLarge': (t.bodyLarge, 16, 24),
      'bodyMedium': (t.bodyMedium, 14, 20),
      'bodySmall': (t.bodySmall, 12, 16),
      'labelLarge': (t.labelLarge, 14, 20),
    };
    for (final MapEntry(key: role, value: (style, size, line))
        in expected.entries) {
      expect(style?.fontSize, size, reason: role);
      expect(
        style!.fontSize! * style.height!,
        closeTo(line, 0.2),
        reason: role,
      );
    }
  });

  test('the font files are bundled with the weights doc 08 uses', () {
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      expect(
        File('assets/fonts/BeVietnamPro-$weight.ttf').existsSync(),
        isTrue,
      );
    }
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final weight in [400, 500, 600, 700]) {
      expect(pubspec, contains('weight: $weight'));
    }
  });

  test('registers the font licence', () async {
    AppConfiguration.registerFontLicenses();

    final entries = await LicenseRegistry.licenses.toList();

    expect(entries.any((e) => e.packages.contains('Be Vietnam Pro')), isTrue);
  });
}

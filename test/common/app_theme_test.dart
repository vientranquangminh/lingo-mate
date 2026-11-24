import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_colors.dart';
import 'package:lingo_mate/common/resources/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Returns the WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    group('$brightness', () {
      final scheme = AppTheme.colorScheme(brightness);
      final app = AppTheme.appColors(brightness);

      test('maps the doc 08 tokens to the scheme', () {
        expect(scheme.brightness, brightness);
        final theme = AppTheme.materialTheme(brightness);
        expect(theme.scaffoldBackgroundColor, scheme.surface);
        expect(theme.extension<AppColors>(), same(app));
      });

      test('body text pairs meet WCAG AA (4.5:1)', () {
        final pairs = {
          'ink on paper': (scheme.onSurface, scheme.surface),
          'ink on surface': (scheme.onSurface, scheme.surfaceContainerLowest),
          'ink on surfaceAlt': (scheme.onSurface, scheme.surfaceContainerHigh),
          'inkMuted on paper': (scheme.onSurfaceVariant, scheme.surface),
          'onBrand on brand': (scheme.onPrimary, scheme.primary),
          'onPartner on partner': (
            scheme.onInverseSurface,
            scheme.inverseSurface,
          ),
          'offline chip': (
            app.engineOffline.foreground,
            app.engineOffline.background,
          ),
          'standard chip': (
            app.engineStandard.foreground,
            app.engineStandard.background,
          ),
          'live chip': (app.engineLive.foreground, app.engineLive.background),
          'billing issue banner': (
            app.billingIssueForeground,
            app.billingIssueBackground,
          ),
        };
        for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
          expect(
            contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$name is ${contrast(fg, bg).toStringAsFixed(2)}:1',
          );
        }
      });
    });
  }

  test('falls back to the light roles outside a themed context', () {
    expect(AppColors.light.lerp(AppColors.dark, 0.7), same(AppColors.dark));
    expect(AppColors.light.lerp(null, 0.7), same(AppColors.light));
  });
}

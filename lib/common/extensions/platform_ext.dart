import 'package:material_ui/material_ui.dart';

/// Tells widgets whether to use the Cupertino or the Material look.
extension AppPlatformContext on BuildContext {
  /// Whether this context uses Cupertino widgets (iOS and macOS).
  bool get isCupertino => switch (Theme.of(this).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
}

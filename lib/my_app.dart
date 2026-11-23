import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:overlay_support/overlay_support.dart';

import 'common/resources/app_config.dart';
import 'common/resources/app_theme.dart';
import 'generated/l10n.dart';
import 'navigation/app_routes.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return OverlaySupport.global(
      child: _isCupertinoPlatform
          ? CupertinoApp.router(
              localizationsDelegates: _localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              debugShowCheckedModeBanner: false,
              builder: (context, child) =>
                  _buildRoot(context, child, cupertino: true),
              routerConfig: router,
            )
          : MaterialApp.router(
              localizationsDelegates: _localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              debugShowCheckedModeBanner: false,
              builder: (context, child) =>
                  _buildRoot(context, child, cupertino: false),
              routerConfig: router,
            ),
    );
  }

  static const _localizationsDelegates = [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  /// Whether the app runs as a Cupertino app (iOS and macOS).
  static bool get _isCupertinoPlatform => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  /// Wraps the routed page in screen scaling, portals and the app themes.
  Widget _buildRoot(
    BuildContext context,
    Widget? child, {
    required bool cupertino,
  }) {
    ScreenUtil.init(
      context,
      designSize: AppConfiguration.mainAppSize,
      splitScreenMode: true,
      minTextAdapt: true,
    );
    final brightness = MediaQuery.platformBrightnessOf(context);
    final page = child ?? Container();
    return Portal(
      child: Theme(
        data: AppTheme.materialTheme(brightness),
        child: cupertino
            ? CupertinoTheme(
                data: AppTheme.cupertinoTheme(brightness),
                child: page,
              )
            : page,
      ),
    );
  }
}

import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:overlay_support/overlay_support.dart';

import 'common/resources/app_config.dart';
import 'common/resources/app_theme.dart';
import 'core/analytics/analytics_service.dart';
import 'core/review/review_reminder.dart';
import 'core/settings/app_locale_sync.dart';
import 'core/settings/user_settings.dart';
import 'env.dart';
import 'features/devtools/presentation/widget/latency_hud.dart';
import 'generated/l10n.dart';
import 'navigation/app_routes.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  /// Uses the first phone language the app supports, else English (AC-11.3).
  static Locale resolveLocale(
    List<Locale>? preferred,
    Iterable<Locale> supported,
  ) {
    for (final locale in preferred ?? const <Locale>[]) {
      for (final candidate in supported) {
        if (candidate.languageCode == locale.languageCode) {
          return candidate;
        }
      }
    }
    return const Locale('en');
  }

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final sync = ref.read(appLocaleSyncProvider)..start();
    final reminder = ref.read(reviewReminderSyncProvider);
    unawaited(reminder());
    _lifecycle = AppLifecycleListener(onResume: sync.pull, onPause: reminder);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLocaleSyncProvider);
    final router = ref.watch(goRouterProvider);
    ref.watch(privacyConsentProvider);
    final appLocale = ref.watch(
      userSettingsProvider.select((s) => s.appLocale),
    );
    final locale = appLocale == null ? null : Locale(appLocale);
    return OverlaySupport.global(
      child: _isCupertinoPlatform
          ? CupertinoApp.router(
              localizationsDelegates: _localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              localeListResolutionCallback: MyApp.resolveLocale,
              debugShowCheckedModeBanner: false,
              builder: (context, child) =>
                  _buildRoot(context, child, cupertino: true),
              routerConfig: router,
            )
          : MaterialApp.router(
              localizationsDelegates: _localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: locale,
              localeListResolutionCallback: MyApp.resolveLocale,
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
    final routed = child ?? Container();
    final page = Env.devtoolsEnabled
        ? Stack(children: [routed, const LatencyHud()])
        : routed;
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

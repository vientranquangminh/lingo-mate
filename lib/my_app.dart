import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:overlay_support/overlay_support.dart';

import 'common/extensions/build_context_ext.dart';
import 'common/resources/app_config.dart';
import 'common/resources/app_theme.dart';
import 'common/widgets/account_merge_prompt.dart';
import 'common/widgets/app_toast.dart';
import 'common/widgets/speak_or_show.dart';
import 'common/widgets/usage_sheet.dart';
import 'core/analytics/analytics_service.dart';
import 'core/auth/auth_models.dart';
import 'core/auth/auth_providers.dart';
import 'core/quota/quota_engine.dart';
import 'core/quota/quota_providers.dart';
import 'core/platform/home_widget.dart';
import 'core/quick_phrases/quick_phrases.dart';
import 'core/review/review_reminder.dart';
import 'core/settings/app_locale_sync.dart';
import 'core/sync/sync_controller.dart';
import 'core/settings/user_settings.dart';
import 'env.dart';
import 'features/devtools/presentation/widget/latency_hud.dart';
import 'generated/l10n.dart';
import 'navigation/app_routes.dart';
import 'navigation/route_const.dart';

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
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    final sync = ref.read(appLocaleSyncProvider)..start();
    _startAccount();
    ref.listenManual(standardQuotaProvider, (previous, next) {
      final status = next.value;
      if (status != null) {
        _warnUsage(previous?.value, status);
      }
    });
    final reminder = ref.read(reviewReminderSyncProvider);
    unawaited(reminder());
    _lifecycle = AppLifecycleListener(onResume: sync.pull, onPause: reminder);
  }

  /// Warns once when Standard use passes 80% of a window and when it runs out (AC-14.6).
  void _warnUsage(QuotaStatus? before, QuotaStatus now) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    final context = overlay?.context;
    if (before == null || context == null || !context.mounted) {
      return;
    }
    final l10n = context.localization;
    final resetAt = now.resetAt;
    if (!before.exhausted && now.exhausted && resetAt != null) {
      showAppToast(
        context,
        l10n.usageReached(TimeOfDay.fromDateTime(resetAt).format(context)),
        actionLabel: l10n.usageSee,
        onAction: () => showUsageSheet(context),
        overlay: overlay,
      );
    } else if (before.fraction < 0.8 && now.fraction >= 0.8 && !now.exhausted) {
      showAppToast(
        context,
        l10n.usageWarning,
        actionLabel: l10n.usageSee,
        onAction: () => showUsageSheet(context),
        overlay: overlay,
      );
    }
  }

  /// Signs in anonymously and listens for email sign-in links (AC-13.1, AC-13.5).
  void _startAccount() {
    final auth = ref.read(authServiceProvider);
    if (auth.available) {
      unawaited(auth.ensureSignedIn().catchError((Object _) {}));
    }
    _links = ref
        .read(incomingLinksProvider)
        .listen((uri) => _onLink(uri), onError: (Object _) {});
  }

  /// Opens the screen an app link asks for: Conversation, Meeting or a quick phrase (F-23).
  Future<void> _openAppLink(AppLink link) async {
    final router = ref.read(goRouterProvider);
    final pair = ref.read(userSettingsProvider).pair;
    switch (link) {
      case ConversationLink():
        unawaited(
          router.pushNamed(
            AppRouteName.conversation,
            queryParameters: {'a': pair.a, 'b': pair.b},
          ),
        );
      case MeetingLink(:final start):
        unawaited(
          router.pushNamed(
            AppRouteName.meeting,
            queryParameters: {if (start) 'start': '1'},
          ),
        );
      case QuickPhraseLink(:final key):
        final catalog = await ref.read(quickPhraseCatalogProvider.future);
        final phrase = catalog.phrase(key);
        final context = rootNavigatorKey.currentState?.overlay?.context;
        if (phrase == null || context == null || !context.mounted) {
          return;
        }
        await speakOrShow(
          context,
          ref,
          text: phrase.text(pair.b),
          lang: pair.b,
          original: phrase.text(pair.a),
        );
    }
  }

  /// Handles an incoming link: an app link, or an email sign-in link that completes or opens the screen that needs the user.
  Future<void> _onLink(Uri uri) async {
    final appLink = AppLink.parse(uri);
    if (appLink != null) {
      await _openAppLink(appLink);
      return;
    }
    if (!ref.read(authServiceProvider).available) {
      return;
    }
    final link = uri.toString();
    final (outcome, result) = await ref
        .read(authServiceProvider)
        .completeEmailLink(link);
    final overlay = rootNavigatorKey.currentState?.overlay;
    final context = overlay?.context;
    if (context == null || !context.mounted) {
      return;
    }
    switch (outcome) {
      case EmailLinkOutcome.signedIn:
        showAppToast(
          context,
          context.localization.signInDone,
          overlay: overlay,
        );
        await promptAccountMerge(context, ref, result);
      case EmailLinkOutcome.needsEmail || EmailLinkOutcome.invalid:
        unawaited(
          ref
              .read(goRouterProvider)
              .pushNamed(
                AppRouteName.emailLink,
                extra: EmailLinkRequest(link, outcome),
              ),
        );
      case EmailLinkOutcome.notALink:
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appLocaleSyncProvider);
    final router = ref.watch(goRouterProvider);
    ref
      ..watch(privacyConsentProvider)
      ..watch(syncControllerProvider)
      ..watch(homeWidgetSyncProvider);
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

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/auth/auth_providers.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/platform/mic_permission.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:lingo_mate/features/onboarding/data/notifier/onboarding_notifier.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:lingo_mate/navigation/route_const.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../language_packs/language_packs_fakes.dart';

void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  late FakeMicPermission mic;
  late FakeTranslationModels translation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    mic = FakeMicPermission(current: MicPermissionStatus.denied);
    translation = FakeTranslationModels();
    FlavorConfig(appFlavor: Flavor.production);
  });

  tearDown(() => db.close());

  /// Overrides for the whole app.
  List<Override> overrides({String device = 'vi'}) => [
    ...packOverrides(
      translation: translation,
      speech: FakeSpeechModelFiles(),
      voices: FakeVoiceChecker(),
      wifi: FakeWifiState(),
    ),
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWithValue(db),
    micPermissionProvider.overrideWithValue(mic),
    systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
    deviceLanguageProvider.overrideWithValue(device),
    onlineProvider.overrideWith((ref) => Stream.value(true)),
    incomingLinksProvider.overrideWithValue(const Stream.empty()),
  ];

  /// Pumps the real app.
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    String device = 'vi',
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: overrides(device: device));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
    return container;
  }

  testWidgets(
    'first launch walks Welcome → I speak → I talk with → packs → Home',
    (tester) async {
      final container = await pumpApp(tester, device: 'ru');

      expect(find.text('Talk to anyone.'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Learn from every chat'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await settle(tester);
      expect(find.text('Live captions & voice'), findsOneWidget);
      expect(find.text('Works without internet'), findsOneWidget);
      expect(find.text('Learn from every chat'), findsOneWidget);
      expect(find.text('Your audio is never saved.'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await settle(tester);

      expect(find.text('I speak'), findsOneWidget);
      expect(container.read(onboardingProvider).mine, 'en');
      await tester.tap(find.text('Tiếng Việt'));
      await settle(tester);
      expect(container.read(onboardingProvider).mine, 'vi');
      await tester.tap(find.text('Continue'));
      await settle(tester);

      expect(find.text('I usually talk with'), findsOneWidget);
      expect(find.textContaining('Tiếng Việt'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'^English, Offline, Live$')),
        findsWidgets,
      );
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(find.text('I usually talk with'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.tap(find.textContaining('Japanese'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);

      expect(find.text('Use it without internet'), findsOneWidget);
      expect(find.text('Wi-Fi recommended: packs are large.'), findsOneWidget);
      expect(find.text('Vietnamese'), findsOneWidget);
      expect(find.text('130 MB'), findsWidgets);
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await settle(tester);

      expect(find.text('Who are you talking to today?'), findsOneWidget);
      final settings = container.read(userSettingsProvider);
      expect(settings.onboardingDone, isTrue);
      expect(settings.myLanguage, 'vi');
      expect(settings.partnerLanguages, ['en', 'ja']);
      expect(mic.requests, 0);
      expect(translation.downloads, isEmpty);
    },
  );

  testWidgets('Download starts the packs for the chosen languages (AC-01.4)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);

    await tester.tap(find.text('Download'));
    await settle(tester);

    expect(translation.downloads, containsAll(['en', 'vi']));
    expect(find.text('Who are you talking to today?'), findsOneWidget);
  });

  testWidgets(
    'onboarding never shows again and Me → Run setup again restarts it (AC-01.5)',
    (tester) async {
      await prefs.setBool('onboarding_done', true);
      await prefs.setString('my_language', 'vi');
      await prefs.setStringList('partner_languages', ['en']);
      final container = await pumpApp(tester);

      expect(find.text('Who are you talking to today?'), findsOneWidget);
      expect(find.text('Vietnamese'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('Me'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Run setup again'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Run setup again'));
      await settle(tester);

      expect(find.text('Talk to anyone.'), findsOneWidget);
      expect(container.read(userSettingsProvider).onboardingDone, isFalse);
      await tester.tap(find.text('Get started'));
      await settle(tester);
      expect(container.read(onboardingProvider).mine, 'vi');
      expect(container.read(onboardingProvider).partners, ['en']);
    },
  );

  testWidgets(
    'the app language switches at once and survives a restart (AC-11.4, AC-11.5)',
    (tester) async {
      final container = await pumpApp(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('App language')));
      await settle(tester);
      await tester.tap(find.text('Tiếng Việt'));
      await settle(tester);

      expect(find.text('Nói chuyện với bất kỳ ai.'), findsOneWidget);
      expect(prefs.getString('app_locale'), 'vi');

      await tester.tap(find.bySemanticsLabel(RegExp('Ngôn ngữ ứng dụng')));
      await settle(tester);
      await tester.tap(find.text('Ngôn ngữ điện thoại (mặc định)'));
      await settle(tester);

      expect(find.text('Talk to anyone.'), findsOneWidget);
      expect(container.read(userSettingsProvider).appLocale, isNull);
    },
  );

  test(
    'phone languages resolve to a supported one, else English (AC-11.3)',
    () {
      const supported = [Locale('en'), Locale('vi')];
      expect(
        MyApp.resolveLocale([const Locale('vi', 'VN')], supported).languageCode,
        'vi',
      );
      expect(
        MyApp.resolveLocale([const Locale('fr')], supported).languageCode,
        'en',
      );
      expect(MyApp.resolveLocale(null, supported).languageCode, 'en');
    },
  );

  test('redirect keeps onboarding first and never returns to it', () {
    expect(
      onboardingRedirect(onboardingDone: false, location: AppRoutePath.home),
      AppRoutePath.welcome,
    );
    expect(
      onboardingRedirect(onboardingDone: false, location: AppRoutePath.setup),
      isNull,
    );
    expect(
      onboardingRedirect(onboardingDone: true, location: AppRoutePath.welcome),
      AppRoutePath.home,
    );
    expect(
      onboardingRedirect(onboardingDone: true, location: AppRoutePath.history),
      isNull,
    );
    expect(
      onboardingRedirect(
        onboardingDone: false,
        location: AppRoutePath.devtools,
      ),
      isNull,
    );
  });
}

/// Lets real asynchronous work finish, then rebuilds.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

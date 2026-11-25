import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/settings/app_preferences.dart';
import 'package:lingo_mate/features/onboarding/presentation/view/welcome_page.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';
import '../phrasebook/phrasebook_test.dart' show settle;

void main() {
  late ConversationFakes fakes;
  late FakeTranslationModels translation;
  late FakeSystemSettings system;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    translation = FakeTranslationModels()..downloaded.addAll(['vi', 'en']);
    system = FakeSystemSettings();
    FlavorConfig(appFlavor: Flavor.production);
  });

  tearDown(() => fakes.db.close());

  /// Pumps the app on Home.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        ...packOverrides(
          translation: translation,
          speech: FakeSpeechModelFiles(),
          voices: FakeVoiceChecker(),
          wifi: FakeWifiState(),
        ),
        ...fakes.overrides(),
        systemSettingsProvider.overrideWithValue(system),
      ],
    );
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

  /// Opens the Me tab.
  Future<void> openMe(WidgetTester tester) async {
    await tester.tap(find.text('Me').last);
    await settle(tester);
  }

  /// Taps [text] after scrolling it into view.
  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await settle(tester);
    await tester.tap(target);
    await settle(tester);
  }

  testWidgets('Me lists Translation & voice, Privacy & data and licenses', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMe(tester);

    expect(find.text('Translation & voice'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Privacy & data'), findsOneWidget);
    expect(find.text('Open-source licenses'), findsOneWidget);

    await tester.tap(find.text('Open-source licenses'));
    await settle(tester);
    expect(find.text('Lingo Mate'), findsWidgets);
  });

  testWidgets('engine, voice, caption and screen choices are saved (AC-10.2)', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await openMe(tester);
    await tester.tap(find.text('Translation & voice'));
    await settle(tester);

    await tapText(tester, 'Prefer Offline');
    await tapText(tester, 'Slow');
    await tapText(tester, 'Large');
    await tapText(tester, 'Keep screen on');

    expect(
      container.read(appPreferencesProvider),
      const AppPreferences(
        engine: EnginePreference.preferOffline,
        voiceSpeed: VoiceSpeed.slow,
        captionSize: CaptionSize.large,
        keepScreenOn: false,
      ),
    );
    expect(fakes.prefs.getString('pref_engine'), 'preferOffline');

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Prefer Offline'), findsOneWidget);
  });

  testWidgets('Conversation keeps the screen on while open', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Conversation'));
    await settle(tester);
    expect(system.screenOn, isTrue);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(system.screenOn, isFalse);
  });

  testWidgets('privacy switches turn analytics and crash reports off', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await openMe(tester);
    await tester.tap(find.text('Privacy & data'));
    await settle(tester);

    await tapText(tester, 'Share usage analytics');
    await tapText(tester, 'Send crash reports');

    final prefs = container.read(appPreferencesProvider);
    expect(prefs.analytics, isFalse);
    expect(prefs.crashReports, isFalse);
  });

  testWidgets(
    'delete all data asks twice, wipes data and packs, and restarts setup (AC-10.3)',
    (tester) async {
      await tester.runAsync(
        () => PhraseRepository(fakes.db).save(
          sourceLang: 'vi',
          sourceText: 'Cảm ơn',
          targetLang: 'en',
          targetText: 'Thank you',
        ),
      );
      final container = await pumpApp(tester);
      await openMe(tester);
      await tester.tap(find.text('Privacy & data'));
      await settle(tester);

      await tapText(tester, 'Delete all data');
      expect(find.text('Delete all data?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        await tester.runAsync(
          () => container.read(phraseRepositoryProvider).watchCount().first,
        ),
        1,
      );

      await tapText(tester, 'Delete all data');
      await tester.tap(find.text('Also remove downloaded language packs'));
      await settle(tester);
      await tester.tap(find.text('Continue'));
      await settle(tester);
      expect(find.text("This can't be undone"), findsOneWidget);
      await tester.tap(find.text('Delete everything'));
      await settle(tester);

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(
        await tester.runAsync(
          () => container.read(phraseRepositoryProvider).watchCount().first,
        ),
        0,
      );
      expect(fakes.prefs.getBool('onboarding_done'), isNull);
      expect(translation.downloaded, isEmpty);
    },
  );

  testWidgets('settings pages lay out at 200% text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    await openMe(tester);
    await tapText(tester, 'Translation & voice');
    await tester.scrollUntilVisible(
      find.text('Keep screen on'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    await tapText(tester, 'Privacy & data');
    await tester.scrollUntilVisible(
      find.text('Delete all data'),
      200,
      scrollable: find.byType(Scrollable).last,
    );

    expect(tester.takeException(), isNull);
  });
}

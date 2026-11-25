import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/features/home/presentation/view/home_page.dart';
import 'package:lingo_mate/features/phrasebook/presentation/widget/quick_tab.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';
import 'phrasebook_test.dart' show settle;

void main() {
  late ConversationFakes fakes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
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
          translation: FakeTranslationModels(),
          speech: FakeSpeechModelFiles(),
          voices: FakeVoiceChecker(),
          wifi: FakeWifiState(),
        ),
        ...fakes.overrides(),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
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

  /// Opens Phrases → Quick.
  Future<void> openQuick(WidgetTester tester) async {
    await tester.tap(find.text('Phrases').last);
    await settle(tester);
    await tester.tap(find.text('Quick'));
    await settle(tester);
  }

  /// Opens the Restaurant situation.
  Future<void> openRestaurant(WidgetTester tester) async {
    await openQuick(tester);
    final restaurant = find.text('Restaurant');
    await tester.scrollUntilVisible(
      restaurant,
      100,
      scrollable: find
          .descendant(
            of: find.byType(QuickTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.runAsync(
      () =>
          Scrollable.ensureVisible(tester.element(restaurant), alignment: 0.5),
    );
    await settle(tester);
    await tester.tap(restaurant);
    await settle(tester);
  }

  testWidgets('Quick shows 8 situations and changes the target language', (
    tester,
  ) async {
    await pumpApp(tester);
    await openQuick(tester);

    expect(find.text('Translate into: English'), findsOneWidget);
    for (final name in [
      'Airport',
      'Hotel',
      'Restaurant',
      'Taxi & directions',
      'Shopping',
      'Health & emergency',
      'Small talk',
      'Meeting basics',
    ]) {
      await tester.scrollUntilVisible(find.text(name), 100);
      expect(find.text(name), findsOneWidget);
    }

    await tester.scrollUntilVisible(find.text('Translate into: English'), -100);
    await tester.tap(find.text('Translate into: English'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Japanese'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Japanese'));
    await settle(tester);
    expect(find.text('Translate into: Japanese'), findsOneWidget);

    await tester.tap(find.text('Restaurant'));
    await settle(tester);
    expect(find.text('Vietnamese → Japanese · works offline'), findsOneWidget);
    expect(find.text('メニューを見せてください。'), findsOneWidget);
  });

  testWidgets(
    'slot chips update both languages and a tap speaks the translation (AC-09.2, AC-09.3)',
    (tester) async {
      await pumpApp(tester);
      await openRestaurant(tester);

      expect(find.text('Có bàn cho 1 người không?'), findsOneWidget);
      expect(find.text('Do you have a table for 1?'), findsOneWidget);

      await tester.tap(find.text('2'));
      await settle(tester);
      expect(find.text('Có bàn cho 2 người không?'), findsOneWidget);
      expect(find.text('Do you have a table for 2?'), findsOneWidget);

      await tester.tap(find.text('Do you have a table for 2?'));
      await settle(tester);
      expect(fakes.tts.spoken, [('Do you have a table for 2?', 'en')]);
    },
  );

  testWidgets('without a voice a tap opens show mode with a hint (AC-09.2)', (
    tester,
  ) async {
    fakes.tts.missingVoices.add('en');
    await pumpApp(tester);
    await openRestaurant(tester);

    await tester.tap(find.text('Could I see the menu?'));
    await settle(tester);

    expect(fakes.tts.spoken, isEmpty);
    expect(find.textContaining('No voice for this language'), findsOneWidget);
    expect(find.bySemanticsLabel('Turn the text around'), findsWidgets);
  });

  testWidgets(
    'long-press shows the phrase large with a speak button (AC-09.4)',
    (tester) async {
      await pumpApp(tester);
      await openRestaurant(tester);

      await tester.longPress(find.text('Could I see the menu?'));
      await settle(tester);
      expect(find.text('Cho tôi xem thực đơn được không?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Speak'));
      await settle(tester);
      expect(fakes.tts.spoken, [('Could I see the menu?', 'en')]);
    },
  );

  testWidgets(
    'a starred phrase shows in Favorites and on Home with See all (AC-09.5)',
    (tester) async {
      await pumpApp(tester);
      await openRestaurant(tester);

      await tester.tap(find.bySemanticsLabel('Add to favorites').at(1));
      await settle(tester);
      expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Could I see the menu?'), findsOneWidget);

      await tester.tap(find.text('Mine'));
      await settle(tester);
      await tester.tap(find.text('Translate').last);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Could I see the menu?'),
        100,
        scrollable: find
            .descendant(
              of: find.byType(HomePage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Favorite phrases'), findsOneWidget);
      await settle(tester);

      await tester.tap(find.text('Could I see the menu?'));
      await settle(tester);
      expect(fakes.tts.spoken, [('Could I see the menu?', 'en')]);

      await tester.tap(find.text('See all'));
      await settle(tester);
      expect(find.text('Translate into: English'), findsOneWidget);
    },
  );

  testWidgets('a quick phrase can be added to the phrasebook', (tester) async {
    final container = await pumpApp(tester);
    await openRestaurant(tester);

    await tester.tap(find.bySemanticsLabel('Save to phrasebook').at(1));
    await settle(tester);

    expect(find.text('Saved to phrasebook'), findsOneWidget);
    final saved = await tester.runAsync(
      () => container
          .read(phraseRepositoryProvider)
          .watch(const PhraseFilter())
          .first,
    );
    expect(saved!.single.phrase.targetText, 'Could I see the menu?');
  });

  testWidgets('Quick and a situation lay out at 200% text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    await openRestaurant(tester);

    expect(find.text('Do you have a table for 1?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

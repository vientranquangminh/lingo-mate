import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/widgets/app_platform_switch.dart';
import 'package:lingo_mate/core/background/background_capture.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/review/review_reminder.dart';
import 'package:lingo_mate/core/review/review_repository.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/review/review_fakes.dart';
import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';

void main() {
  late ConversationFakes fakes;
  late FakeReminderScheduler scheduler;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    scheduler = FakeReminderScheduler();
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
        reviewReminderSchedulerProvider.overrideWithValue(scheduler),
        notificationPermissionProvider.overrideWithValue(() async {}),
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

  /// Saves one vi → en phrase.
  Future<void> savePhrase(WidgetTester tester) => tester.runAsync(
    () => PhraseRepository(fakes.db).save(
      sourceLang: 'vi',
      sourceText: 'Cảm ơn',
      targetLang: 'en',
      targetText: 'Thank you',
    ),
  );

  /// Opens Phrases and then Review from its banner.
  Future<void> openReview(WidgetTester tester) async {
    await tester.tap(find.text('Phrases').last);
    await settle(tester);
    await tester.tap(find.text('cards to review today'));
    await settle(tester);
  }

  testWidgets('no banner when nothing is due', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Phrases').last);
    await settle(tester);

    expect(find.textContaining('to review today'), findsNothing);
  });

  testWidgets(
    'shows due cards one by one, reveals, grades and finishes (AC-16.1)',
    (tester) async {
      await savePhrase(tester);
      await pumpApp(tester);
      await openReview(tester);

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('0 of 2'), findsOneWidget);
      expect(find.text('Cảm ơn'), findsOneWidget);
      expect(find.text('Thank you'), findsNothing);

      await tester.tap(find.text('Show answer'));
      await settle(tester);
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.text('Good · 1 day'), findsOneWidget);

      await tester.tap(find.text('Good · 1 day'));
      await settle(tester);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.text('Cảm ơn'), findsNothing);

      await tester.tap(find.text('Tap to show the answer'));
      await settle(tester);
      await tester.tap(find.text('Easy · 1 day'));
      await settle(tester);

      expect(find.text('All done for today'), findsOneWidget);
      expect(find.text('You reviewed 2 cards.'), findsOneWidget);
      expect(find.text('1-day streak'), findsOneWidget);
      final due = await tester.runAsync(
        () => ReviewRepository(fakes.db).watchDueCount().first,
      );
      expect(due, 0);
    },
  );

  testWidgets('a card graded Again comes back at the end of the session', (
    tester,
  ) async {
    await savePhrase(tester);
    await pumpApp(tester);
    await openReview(tester);

    await tester.tap(find.text('Show answer'));
    await settle(tester);
    await tester.tap(find.text('Again · 1 day'));
    await settle(tester);
    expect(find.text('0 of 2'), findsOneWidget);
    expect(find.text('Thank you'), findsOneWidget);

    await tester.tap(find.text('Show answer'));
    await settle(tester);
    await tester.tap(find.textContaining('Good ·'));
    await settle(tester);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('Cảm ơn'), findsOneWidget);

    await tester.tap(find.text('Show answer'));
    await settle(tester);
    await tester.tap(find.textContaining('Good ·'));
    await settle(tester);
    expect(find.text('All done for today'), findsOneWidget);
  });

  testWidgets('with nothing due the page says so and offers the reminder', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container.read(goRouterProvider).push('/phrases/review');
    await settle(tester);

    expect(find.text('Nothing to review'), findsOneWidget);
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(find.text('Reminder time'), findsNothing);
  });

  testWidgets(
    'turning the reminder on schedules it when cards are due (AC-16.3)',
    (tester) async {
      await savePhrase(tester);
      await pumpApp(tester);
      await openReview(tester);

      await tester.tap(find.bySemanticsLabel('Reminder settings'));
      await settle(tester);
      await tester.tap(find.byType(AppPlatformSwitch));
      await settle(tester);

      expect(find.text('Reminder time'), findsOneWidget);
      expect(scheduler.scheduled, isNotNull);
      expect(scheduler.scheduled!.hour, 20);
      expect(scheduler.title, 'Time to review');
    },
  );
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

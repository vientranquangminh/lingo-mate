import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/review/review_reminder.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';
import '../learning/learning_pages_test.dart' show settle;

void main() {
  late ConversationFakes fakes;
  final now = DateTime(2026, 11, 25, 9);

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

  /// Adds [seconds] of Standard use at [at].
  Future<void> use(WidgetTester tester, int seconds, DateTime at) =>
      tester.runAsync(
        () => fakes.db
            .into(fakes.db.usageLedger)
            .insert(
              UsageLedgerCompanion.insert(
                engine: 'standard',
                seconds: seconds,
                at: at,
              ),
            ),
      );

  /// Pumps the app on Home with a fixed clock.
  Future<void> pumpApp(WidgetTester tester) async {
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
        reviewClockProvider.overrideWithValue(() => now),
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
  }

  testWidgets(
    'Me shows the plan card; the usage sheet shows both windows (AC-14.7)',
    (tester) async {
      await use(tester, 21 * 60, now.subtract(const Duration(hours: 1)));
      await pumpApp(tester);
      await tester.tap(find.text('Me').last);
      await settle(tester);

      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('21/60 min'), findsOneWidget);

      await tester.tap(find.text('Free plan'));
      await settle(tester);
      expect(find.text('This 5-hour window'), findsOneWidget);
      expect(find.text('21/30 min · resets 13:00'), findsOneWidget);
      expect(find.textContaining('21/60 min · resets Wed'), findsOneWidget);
      expect(
        find.text('Offline translation is never counted.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('crossing 80% warns once (AC-14.6)', (tester) async {
    await use(tester, 20 * 60, now.subtract(const Duration(minutes: 30)));
    await pumpApp(tester);
    expect(find.text("You've used 80% of your Standard time."), findsNothing);

    await use(tester, 5 * 60, now.subtract(const Duration(minutes: 1)));
    await settle(tester);
    expect(find.text("You've used 80% of your Standard time."), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('running out says so and points to the usage sheet (AC-14.6)', (
    tester,
  ) async {
    await use(tester, 25 * 60, now.subtract(const Duration(minutes: 30)));
    await pumpApp(tester);

    await use(tester, 5 * 60, now.subtract(const Duration(minutes: 1)));
    await settle(tester);
    expect(
      find.textContaining('Standard time is used up until'),
      findsOneWidget,
    );
    await tester.tap(find.text('See usage'));
    await settle(tester);
    expect(find.text('This week'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}

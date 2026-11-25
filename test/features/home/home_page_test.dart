import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/features/listen/presentation/view/listen_page.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';

void main() {
  late ConversationFakes fakes;
  late FakeTranslationModels translation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'my_language': 'vi',
      'partner_languages': ['en', 'ja'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    translation = FakeTranslationModels();
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

  testWidgets('shows the pair, engine, modes and offline status', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Vietnamese'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Who are you talking to today?'), findsOneWidget);
    expect(find.text('Conversation'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Meeting'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('Offline ready'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await settle(tester);
    expect(find.text('Offline ready: no languages'), findsOneWidget);
    expect(find.text('Vietnamese not downloaded · 130 MB'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Phrases'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
  });

  testWidgets('the Listen card opens Listen from the partner language', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Listen'));
    await settle(tester);

    expect(find.byType(ListenPage), findsOneWidget);
    expect(find.bySemanticsLabel("Speaker's language: English"), findsOneWidget);
  });

  testWidgets('the swap button turns the pair around', (tester) async {
    final container = await pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Swap languages'));
    await settle(tester);

    expect(
      container.read(userSettingsProvider).pair,
      const LanguagePair('en', 'vi'),
    );
  });

  testWidgets('tapping a language picks another one', (tester) async {
    final container = await pumpApp(tester);

    await tester.tap(find.text('English'));
    await settle(tester);
    await tester.tap(find.text('Japanese · 日本語'));
    await settle(tester);

    expect(
      container.read(userSettingsProvider).pair,
      const LanguagePair('vi', 'ja'),
    );
  });

  testWidgets('Conversation opens the split screen for the pair', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Conversation'));
    await settle(tester);

    expect(find.byType(RotatedBox), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('VIETNAMESE'), findsOneWidget);
  });

  testWidgets('Continue opens the last session', (tester) async {
    await tester.runAsync(() async {
      final id = await fakes.sessions.start(
        mode: SessionMode.conversation,
        engine: EngineKind.standard,
        pair: const LanguagePair('vi', 'en'),
      );
      await fakes.sessions.addUtterance(
        id,
        const NewUtterance(
          speaker: 'a',
          sourceLang: 'vi',
          sourceText: 'Xin chào',
          targetLang: 'en',
          targetText: 'Hello',
          startMs: 0,
          endMs: 1000,
          engine: UtteranceEngine.standard,
        ),
      );
      await fakes.sessions.finish(id);
    });
    await pumpApp(tester);
    await tester.dragUntilVisible(
      find.text('Continue: Hello'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await settle(tester);

    await tester.tap(find.text('Continue: Hello'));
    await settle(tester);

    expect(find.text('Hello'), findsWidgets);
    expect(find.text('Xin chào'), findsOneWidget);
  });

  testWidgets('tabs switch to History and Me', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('History'));
    await settle(tester);
    expect(find.textContaining('No sessions yet'), findsOneWidget);

    await tester.tap(find.text('Me'));
    await settle(tester);
    expect(find.text('Run setup again'), findsOneWidget);
    expect(find.text('Offline packs'), findsOneWidget);
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

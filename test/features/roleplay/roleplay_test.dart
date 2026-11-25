import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/feature_switches.dart';
import 'package:lingo_mate/core/learning/learning_assistant.dart';
import 'package:lingo_mate/core/learning/learning_models.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';
import '../learning/learning_pages_test.dart' show settle;

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

  test('the assistant reads the partner line and feedback on the learner line', () async {
    final assistant = GeminiLearningAssistant(
      ({required system, required user}) async =>
          '{"reply":"Sure!","replyTranslation":"Được!",'
          '"feedback":{"improved":"Can I have water?","meaning":"Cho tôi nước",'
          '"note":"Dùng Can I"}}',
    );

    final turn = await assistant.roleplay(
      situation: 'restaurant',
      messages: const [RoleplayMessage(fromLearner: true, text: 'Give water')],
      targetLang: 'en',
      userLang: 'vi',
    );

    expect(turn.reply, 'Sure!');
    expect(turn.feedback!.original, 'Give water');
    expect(turn.feedback!.improved, 'Can I have water?');
    expect(turn.feedback!.meaning, 'Cho tôi nước');
  });

  /// Pumps the app and opens the restaurant situation.
  Future<ProviderContainer> pumpSituation(WidgetTester tester) async {
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
    container.read(goRouterProvider).push('/phrases/quick/restaurant');
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
    return container;
  }

  testWidgets(
    'the partner opens, the learner answers and gets feedback to save (AC-22.1)',
    (tester) async {
      await pumpSituation(tester);

      await tester.tap(find.bySemanticsLabel('Practise this situation'));
      await settle(tester);
      expect(find.text('Practise: Restaurant'), findsOneWidget);
      expect(find.text('Good evening! Table for two?'), findsOneWidget);
      expect(find.text('Chào buổi tối! Bàn cho hai người ạ?'), findsOneWidget);
      expect(fakes.learning.roleplayAsked.first, isEmpty);

      await tester.enterText(find.byType(TextField), 'Yes two people table');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await settle(tester);

      expect(find.text('Yes two people table'), findsOneWidget);
      expect(find.text('Of course, follow me.'), findsOneWidget);
      expect(find.text('Yes, a table for two, please.'), findsOneWidget);
      expect(
        fakes.learning.roleplayAsked.last.last.text,
        'Yes two people table',
      );

      await tester.tap(find.bySemanticsLabel('Save to phrasebook'));
      await settle(tester);
      final saved = await tester.runAsync(
        () => PhraseRepository(fakes.db).watch(const PhraseFilter()).first,
      );
      expect(saved!.single.phrase.targetText, 'Yes, a table for two, please.');
      expect(saved.single.phrase.sourceText, 'Vâng, cho một bàn hai người.');
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('a failed turn offers Try again', (tester) async {
    fakes.learning.error = StateError('offline');
    await pumpSituation(tester);
    await tester.tap(find.bySemanticsLabel('Practise this situation'));
    await settle(tester);

    expect(find.text('Try again'), findsOneWidget);
    fakes.learning.error = null;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Good evening! Table for two?'), findsOneWidget);
  });

  testWidgets('the roleplay kill switch hides Practise', (tester) async {
    fakes.switches = const FeatureSwitches(roleplay: false);
    await pumpSituation(tester);

    expect(find.bySemanticsLabel('Practise this situation'), findsNothing);
  });
}

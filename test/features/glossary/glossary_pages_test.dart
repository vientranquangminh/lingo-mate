import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/widgets/app_platform_switch.dart';
import 'package:lingo_mate/core/glossary/glossary_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
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

  testWidgets('creates a set, adds a term and uses it in sessions (AC-18.1)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Me').last);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Glossary'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('Glossary'));
    await settle(tester);

    expect(find.text('No glossary sets yet. Add one with +.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('New glossary set'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Client A');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Client A'), findsOneWidget);
    expect(find.text('No terms yet. Add one with +.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Add term'));
    await settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'deploy');
    await tester.enterText(fields.at(1), 'triển khai');
    await tester.enterText(fields.at(2), 'not "phát hành"');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('deploy'), findsOneWidget);
    expect(find.text('triển khai'), findsOneWidget);
    expect(find.text('not "phát hành"'), findsOneWidget);

    await tester.tap(find.byType(AppPlatformSwitch));
    await settle(tester);
    final terms = await tester.runAsync(
      () => GlossaryRepository(fakes.db).termsIn('We deploy today'),
    );
    expect(terms, {'deploy': 'triển khai'});

    await tester.tap(find.bySemanticsLabel('Back').first);
    await settle(tester);
    expect(find.text('1 term · In use'), findsOneWidget);
  });

  testWidgets('editing and deleting a term', (tester) async {
    await tester.runAsync(() async {
      final repo = GlossaryRepository(fakes.db);
      final id = await repo.createSet('Client A');
      await repo.addTerm(id, term: 'deploy', translation: 'triển khai');
    });
    await pumpApp(tester);
    await tester.tap(find.text('Me').last);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Glossary'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await settle(tester);
    await tester.tap(find.text('Glossary'));
    await settle(tester);
    await tester.tap(find.text('Client A'));
    await settle(tester);

    await tester.tap(find.text('deploy'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(1), 'phát hành');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('phát hành'), findsOneWidget);

    await tester.longPress(find.text('deploy'));
    await settle(tester);
    await tester.tap(find.text('Delete term'));
    await settle(tester);
    expect(find.text('No terms yet. Add one with +.'), findsOneWidget);
  });
}

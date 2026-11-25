import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/platform/home_widget.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/quick_phrases/quick_phrases.dart';
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

  test('app links are read from lingomate://open/...', () {
    expect(
      AppLink.parse(Uri.parse('lingomate://open/conversation')),
      const ConversationLink(),
    );
    expect(
      AppLink.parse(Uri.parse('lingomate://open/meeting?start=1')),
      const MeetingLink(start: true),
    );
    expect(
      AppLink.parse(
        Uri.parse('lingomate://open/quick?key=airport.where_checkin'),
      ),
      const QuickPhraseLink('airport.where_checkin'),
    );
    expect(
      AppLink.parse(Uri.parse('https://example.com/conversation')),
      isNull,
    );
    expect(AppLink.parse(Uri.parse('lingomate://open/unknown')), isNull);
  });

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

  testWidgets(
    'the widget gets up to four starred phrases in my language (AC-23.1)',
    (tester) async {
      await tester.runAsync(() async {
        var at = DateTime(2026, 11, 25, 9);
        final favorites = QuickPhraseFavorites(
          fakes.db,
          now: () => at = at.add(const Duration(seconds: 1)),
        );
        for (final key in [
          'airport.where_gate',
          'airport.bags',
          'airport.aisle_seat',
          'airport.window_seat',
          'airport.where_checkin',
        ]) {
          await favorites.set(key, 'vi', 'en', true);
        }
      });
      await pumpApp(tester);

      final last = fakes.widget.updates.last;
      expect(last, hasLength(4));
      expect(last.first.label, 'Quầy làm thủ tục ở đâu?');
    },
  );

  testWidgets(
    'the widget button opens Conversation on the current pair (AC-23.1)',
    (tester) async {
      await pumpApp(tester);

      fakes.links.add(Uri.parse('lingomate://open/conversation'));
      await settle(tester);

      expect(find.text('VIETNAMESE'), findsOneWidget);
      expect(find.text('ENGLISH'), findsOneWidget);
    },
  );

  testWidgets('a widget phrase is said in the partner language (AC-23.1)', (
    tester,
  ) async {
    await pumpApp(tester);

    fakes.links.add(
      Uri.parse('lingomate://open/quick?key=airport.where_checkin'),
    );
    await settle(tester);

    expect(fakes.tts.spoken.last, ('Where is the check-in counter?', 'en'));
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/widgets/app_selectable_chip.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';

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

  PhraseRepository phrases() => PhraseRepository(fakes.db);

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

  /// Opens the Phrases tab.
  Future<void> openPhrases(WidgetTester tester) async {
    await tester.tap(find.text('Phrases').last);
    await settle(tester);
  }

  testWidgets('empty phrasebook explains how to save lines', (tester) async {
    await pumpApp(tester);
    await openPhrases(tester);

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Quick'), findsOneWidget);
    expect(find.textContaining('No phrases yet'), findsOneWidget);
  });

  testWidgets(
    'lists phrases newest first and filters by pair, tag, ★ and search',
    (tester) async {
      await tester.runAsync(() async {
        final repo = phrases();
        final thanks = await repo.save(
          sourceLang: 'vi',
          sourceText: 'Cảm ơn nhiều',
          targetLang: 'en',
          targetText: 'Thank you so much',
        );
        await repo.setFavorite(thanks.id, true);
        final bill = await repo.save(
          sourceLang: 'vi',
          sourceText: 'Tính tiền giúp tôi',
          targetLang: 'en',
          targetText: 'Could we get the bill?',
        );
        await repo.addTag(bill.id, 'Food');
        await repo.save(
          sourceLang: 'ja',
          sourceText: '一番近い駅はどこですか？',
          targetLang: 'en',
          targetText: "Where's the nearest train station?",
        );
      });
      await pumpApp(tester);
      await openPhrases(tester);

      expect(find.text('Search 3 phrases'), findsOneWidget);
      expect(find.text('Thank you so much'), findsOneWidget);
      expect(find.text('Food'), findsWidgets);

      await tester.ensureVisible(find.text('JA ⇄ EN'));
      await tester.tap(find.text('JA ⇄ EN'));
      await settle(tester);
      expect(find.text("Where's the nearest train station?"), findsOneWidget);
      expect(find.text('Thank you so much'), findsNothing);

      await tester.ensureVisible(find.text('All'));
      await tester.tap(find.text('All'));
      await settle(tester);
      await tester.ensureVisible(
        find.widgetWithText(AppSelectableChip, 'Food'),
      );
      await tester.tap(find.widgetWithText(AppSelectableChip, 'Food'));
      await settle(tester);
      expect(find.text('Could we get the bill?'), findsOneWidget);
      expect(find.text('Thank you so much'), findsNothing);

      await tester.ensureVisible(find.text('All'));
      await tester.tap(find.text('All'));
      await settle(tester);
      await tester.ensureVisible(find.text('★ Favorites'));
      await tester.tap(find.text('★ Favorites'));
      await settle(tester);
      expect(find.text('Thank you so much'), findsOneWidget);
      expect(find.text('Could we get the bill?'), findsNothing);

      await tester.ensureVisible(find.text('All'));
      await tester.tap(find.text('All'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'tinh tien');
      await settle(tester);
      expect(find.text('Could we get the bill?'), findsOneWidget);
      expect(find.text('Thank you so much'), findsNothing);
    },
  );

  testWidgets(
    'add phrase proposes an editable translation and saves (AC-08.3)',
    (tester) async {
      final container = await pumpApp(tester);
      await openPhrases(tester);

      await tester.tap(find.bySemanticsLabel('Add phrase'));
      await settle(tester);
      expect(find.text('From: Vietnamese'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Xin chào');
      await settle(tester);
      await tester.tap(find.text('Translate'));
      await settle(tester);
      expect(find.text('[en] Xin chào'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Hello there');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.text('Saved to phrasebook'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);
      final saved = await tester.runAsync(
        () => container.read(phraseRepositoryProvider).watchCount().first,
      );
      expect(saved, 1);
    },
  );

  testWidgets(
    'saving the same sentence again says it is already there (AC-08.2)',
    (tester) async {
      await tester.runAsync(
        () => phrases().save(
          sourceLang: 'vi',
          sourceText: 'Xin chào',
          targetLang: 'en',
          targetText: 'Hello',
        ),
      );
      await pumpApp(tester);
      await openPhrases(tester);
      await tester.tap(find.bySemanticsLabel('Add phrase'));
      await settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Xin chào');
      await tester.enterText(find.byType(TextField).last, 'Hi');
      await settle(tester);
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(find.text('Already in phrasebook'), findsOneWidget);
      expect(find.text('Add phrase'), findsOneWidget);
    },
  );

  testWidgets(
    'detail plays both sides, tags, notes and deletes with Undo (AC-08.5, AC-08.6)',
    (tester) async {
      await tester.runAsync(
        () => phrases().save(
          sourceLang: 'vi',
          sourceText: 'Cảm ơn',
          targetLang: 'en',
          targetText: 'Thank you',
        ),
      );
      await pumpApp(tester);
      await openPhrases(tester);
      await tester.tap(find.text('Thank you'));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('Play Vietnamese'));
      await tester.tap(find.bySemanticsLabel('Play English'));
      await settle(tester);
      expect(fakes.tts.spoken, [('Cảm ơn', 'vi'), ('Thank you', 'en')]);

      await tester.tap(find.text('+ Add tag'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Travel');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Travel'), findsOneWidget);

      await tester.tap(find.text('Add a note'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'polite');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('polite'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Favorite'));
      await settle(tester);
      expect(find.bySemanticsLabel('Remove from favorites'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Delete'));
      await settle(tester);
      expect(find.text('Phrase deleted'), findsOneWidget);
      expect(find.text('Thank you'), findsNothing);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(find.text('Thank you'), findsOneWidget);
    },
  );

  testWidgets(
    'a Conversation line saves in two taps, linked to its session (AC-02.6, AC-08.1)',
    (tester) async {
      fakes.recognizer.texts.add('Tính tiền giúp tôi');
      await pumpApp(tester);
      await tester.tap(find.text('Conversation'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('Microphone for Vietnamese'));
      await settle(tester);
      expect(find.text('Listening…'), findsOneWidget);
      fakes.nowMs += 1000;
      fakes.capture
        ..add(pcm(1000, amplitude: 4000))
        ..add(pcm(700));
      await settle(tester);

      await tester.longPress(find.text('[en] Tính tiền giúp tôi'));
      await settle(tester);
      await tester.tap(find.text('Save to phrasebook'));
      await settle(tester);

      expect(find.text('Saved to phrasebook'), findsOneWidget);
      final saved = await tester.runAsync(
        () => phrases().watch(const PhraseFilter()).first,
      );
      expect(saved!.single.phrase.targetText, '[en] Tính tiền giúp tôi');
      expect(saved.single.sessionId, isNotNull);
    },
  );

  testWidgets(
    'a transcript line saves to the phrasebook and shows a bookmark',
    (tester) async {
      await tester.runAsync(() async {
        final sessions = SessionRepository(fakes.db);
        final id = await sessions.start(
          mode: SessionMode.conversation,
          engine: EngineKind.standard,
          pair: const LanguagePair('vi', 'en'),
        );
        await sessions.addUtterance(
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
        await sessions.finish(id);
        await sessions.rename(id, 'Lunch');
      });
      await pumpApp(tester);
      await tester.tap(find.text('History').last);
      await settle(tester);
      await tester.tap(find.text('Lunch'));
      await settle(tester);

      await tester.longPress(find.text('Hello'));
      await settle(tester);
      await tester.tap(find.text('Save to phrasebook'));
      await settle(tester);

      expect(find.text('Saved to phrasebook'), findsOneWidget);
      expect(find.bySemanticsLabel('Saved to phrasebook'), findsWidgets);
      final saved = await tester.runAsync(
        () => phrases().watch(const PhraseFilter()).first,
      );
      expect(saved!.single.sessionTitle, 'Lunch');
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

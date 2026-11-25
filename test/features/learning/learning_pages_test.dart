import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/config/feature_switches.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/learning/learning_models.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';

void main() {
  late ConversationFakes fakes;
  late FakeSystemSettings system;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    system = FakeSystemSettings();
    FlavorConfig(appFlavor: Flavor.production);
  });

  tearDown(() => fakes.db.close());

  /// Pumps the app and opens [location].
  Future<void> pumpAt(
    WidgetTester tester,
    String location, {
    bool reviewEnabled = true,
  }) async {
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
        ...fakes.overrides(reviewEnabled: reviewEnabled),
        systemSettingsProvider.overrideWithValue(system),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await settle(tester);
    container.read(goRouterProvider).push(location);
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
  }

  /// Saves a finished session of [mode] with [lines] lines lasting [durationSec].
  Future<String> seed(
    WidgetTester tester, {
    SessionMode mode = SessionMode.conversation,
    int lines = 4,
    int durationSec = 60,
  }) async => (await tester.runAsync(() async {
    final repo = SessionRepository(fakes.db);
    final id = await repo.start(
      mode: mode,
      engine: EngineKind.standard,
      pair: const LanguagePair('vi', 'en'),
    );
    for (var i = 0; i < lines; i++) {
      await repo.addUtterance(
        id,
        NewUtterance(
          speaker: mode == SessionMode.conversation
              ? (i.isEven ? 'a' : 'b')
              : null,
          sourceLang: 'vi',
          sourceText: i == 0 ? 'Tôi muốn hoá đơn' : 'Câu $i',
          targetLang: 'en',
          targetText: 'Line $i',
          startMs: i * 1000,
          endMs: i * 1000 + 900,
          engine: UtteranceEngine.standard,
        ),
      );
    }
    await repo.finish(id);
    await (fakes.db.update(fakes.db.sessions)..where((s) => s.id.equals(id)))
        .write(SessionsCompanion(durationSec: Value(durationSec)));
    return id;
  }))!;

  group('summary (F-20)', () {
    testWidgets(
      'a meeting of 3 minutes can be summarised, stored and shared (AC-20.1, AC-20.2)',
      (tester) async {
        final id = await seed(
          tester,
          mode: SessionMode.meeting,
          durationSec: 200,
        );
        await pumpAt(tester, '/history/$id');

        await tester.tap(find.text('Summarize'));
        await settle(tester);

        expect(find.text('Summary'), findsOneWidget);
        expect(
          find.text('Nhóm thống nhất giao bản thử vào thứ Sáu.'),
          findsOneWidget,
        );
        expect(find.text('• Minh gửi bản thử trước thứ Sáu'), findsOneWidget);
        expect(fakes.learning.lastSummaryLang, 'vi');
        final stored = await tester.runAsync(
          () => SessionRepository(fakes.db).load(id),
        );
        expect(
          SessionRecap.decode(stored!.session.summary),
          fakes.learning.recap,
        );

        await tester.tap(find.bySemanticsLabel('Share summary'));
        await settle(tester);
        expect(system.shared, contains('Action items\n• Minh gửi bản thử'));
      },
    );

    testWidgets('the summary kill switch hides Summarize', (tester) async {
      fakes.switches = const FeatureSwitches(summary: false);
      final id = await seed(
        tester,
        mode: SessionMode.meeting,
        durationSec: 200,
      );
      await pumpAt(tester, '/history/$id');

      expect(find.text('Summarize'), findsNothing);
    });

    testWidgets('short sessions and conversations offer no summary', (
      tester,
    ) async {
      final id = await seed(tester, mode: SessionMode.listen, durationSec: 120);
      await pumpAt(tester, '/history/$id');

      expect(find.text('Summarize'), findsNothing);
    });

    testWidgets('offline the button is disabled with "Needs internet"', (
      tester,
    ) async {
      fakes.online = false;
      final id = await seed(
        tester,
        mode: SessionMode.meeting,
        durationSec: 200,
      );
      await pumpAt(tester, '/history/$id');

      expect(find.text('Needs internet'), findsOneWidget);
      await tester.tap(find.text('Summarize'));
      await settle(tester);
      expect(fakes.learning.asked, isEmpty);
    });
  });

  group('post-session review (F-17)', () {
    testWidgets('lists tips with Save after 3 user lines (AC-17.1, AC-17.2)', (
      tester,
    ) async {
      final id = await seed(tester, lines: 6);
      await pumpAt(tester, '/history/$id');

      await tester.tap(find.text('How would a native say it?'));
      await settle(tester);

      expect(find.text('How a native would say it'), findsOneWidget);
      expect(find.text('You said'), findsOneWidget);
      expect(find.text('Could we have the bill, please?'), findsOneWidget);
      expect(find.text('Lịch sự và tự nhiên hơn.'), findsOneWidget);
      expect(fakes.learning.asked.single, hasLength(3));

      await tester.tap(find.text('Save'));
      await settle(tester);
      final saved = await tester.runAsync(
        () => PhraseRepository(fakes.db).watch(const PhraseFilter()).first,
      );
      expect(
        saved!.single.phrase.targetText,
        'Could we have the bill, please?',
      );
      expect(saved.single.phrase.sourceText, 'Tôi muốn hoá đơn');
    });

    testWidgets('needs 3 user lines and the Remote Config flag', (
      tester,
    ) async {
      final short = await seed(tester, lines: 4);
      await pumpAt(tester, '/history/$short');

      expect(find.text('How would a native say it?'), findsNothing);
    });

    testWidgets('is hidden while ff_post_session_review is off', (
      tester,
    ) async {
      final id = await seed(tester, lines: 6);
      await pumpAt(tester, '/history/$id', reviewEnabled: false);

      expect(find.text('How would a native say it?'), findsNothing);
    });

    testWidgets('offline it is disabled with "Needs internet" (AC-17.3)', (
      tester,
    ) async {
      fakes.online = false;
      final id = await seed(tester, lines: 6);
      await pumpAt(tester, '/history/$id');

      expect(find.text('Needs internet'), findsOneWidget);
      await tester.tap(find.text('How would a native say it?'));
      await settle(tester);
      expect(find.text('You said'), findsNothing);
    });

    testWidgets('a failed review offers Try again', (tester) async {
      fakes.learning.error = StateError('offline');
      final id = await seed(tester, lines: 6);
      await pumpAt(tester, '/history/$id/review');

      expect(find.text('Try again'), findsOneWidget);
      fakes.learning.error = null;
      await tester.tap(find.text('Try again'));
      await settle(tester);
      expect(find.text('You said'), findsOneWidget);
    });
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

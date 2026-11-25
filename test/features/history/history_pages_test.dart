import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/learning/learning_assistant.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:lingo_mate/features/history/presentation/view/history_page.dart';
import 'package:lingo_mate/features/history/presentation/view/transcript_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:lingo_mate/navigation/route_const.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records what the share sheet was asked to show.
class _FakeSystemSettings implements SystemSettings {
  String? shared;

  @override
  Future<bool> installTtsVoice() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> shareText(String text, {String? subject}) async {
    shared = text;
    return true;
  }

  final opened = <String>[];

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);
    return true;
  }

  @override
  Future<bool> keepScreenOn(bool on) async => true;
}

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late _FakeSystemSettings system;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
    system = _FakeSystemSettings();
  });

  tearDown(() => db.close());

  /// Saves a finished Conversation with [lines] of (original, translation, engine).
  Future<String> seed(
    List<(String, String, UtteranceEngine)> lines, {
    String? title,
  }) async {
    final id = await repo.start(
      mode: SessionMode.conversation,
      engine: EngineKind.standard,
      pair: const LanguagePair('vi', 'en'),
    );
    var t = 0;
    for (final (source, target, engine) in lines) {
      await repo.addUtterance(
        id,
        NewUtterance(
          speaker: t.isEven ? 'a' : 'b',
          sourceLang: 'vi',
          sourceText: source,
          targetLang: 'en',
          targetText: target,
          startMs: t * 60000,
          endMs: t * 60000 + 3000,
          engine: engine,
        ),
      );
      t++;
    }
    await repo.finish(id);
    if (title != null) {
      await repo.rename(id, title);
    }
    return id;
  }

  /// Pumps history with its transcript route.
  Future<void> pumpHistory(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutePath.history,
      routes: [
        GoRoute(
          name: AppRouteName.history,
          path: AppRoutePath.history,
          builder: (context, state) => const HistoryPage(),
          routes: [
            GoRoute(
              name: AppRouteName.transcript,
              path: AppRoutePath.transcript,
              builder: (context, state) =>
                  TranscriptPage(sessionId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(seconds: 1));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          systemSettingsProvider.overrideWithValue(system),
          sharedPreferencesProvider.overrideWithValue(prefs),
          postSessionReviewEnabledProvider.overrideWithValue(false),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            ScreenUtil.init(context, designSize: AppConfiguration.mainAppSize);
            return child!;
          },
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('empty history explains where sessions go', (tester) async {
    await pumpHistory(tester);

    expect(find.textContaining('No sessions yet'), findsOneWidget);
  });

  testWidgets(
    'lists sessions under Today with pair, duration and first line (AC-07.1)',
    (tester) async {
      await tester.runAsync(
        () => seed([
          ('Xin chào', 'Hello there', UtteranceEngine.standard),
        ], title: 'Lunch with Kenji'),
      );
      await pumpHistory(tester);

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Lunch with Kenji'), findsOneWidget);
      expect(find.text('VI⇄EN'), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);
    },
  );

  testWidgets(
    'search finds lines across sessions and opens the transcript (AC-07.3)',
    (tester) async {
      await tester.runAsync(() async {
        await seed([
          (
            'Hoàn tiền trong 24 giờ',
            'Refunds within 24 hours',
            UtteranceEngine.standard,
          ),
        ], title: 'Client meeting');
        await seed([
          ('Cảm ơn', 'Thank you', UtteranceEngine.offline),
        ], title: 'Taxi');
      });
      await pumpHistory(tester);

      await tester.enterText(find.byType(TextField), 'hoan');
      await settle(tester);

      expect(find.text('Refunds within 24 hours'), findsOneWidget);
      expect(find.text('Thank you'), findsNothing);

      await tester.tap(find.text('Refunds within 24 hours'));
      await settle(tester);
      expect(find.text('Client meeting'), findsOneWidget);
    },
  );

  testWidgets(
    'transcript shows lines with a fallback badge, shares and deletes',
    (tester) async {
      late String id;
      await tester.runAsync(() async {
        id = await seed([
          (
            'Bạn có thể trình bày không?',
            'Could you walk us through it?',
            UtteranceEngine.standard,
          ),
          (
            'Mạng chập chờn',
            'The connection is unstable',
            UtteranceEngine.offlineFallback,
          ),
          ('Cảm ơn', 'Thanks', UtteranceEngine.standard),
        ], title: 'Client meeting');
      });
      await pumpHistory(tester);
      await tester.tap(find.text('Client meeting'));
      await settle(tester);

      expect(find.text('Could you walk us through it?'), findsOneWidget);
      expect(find.text('Bạn có thể trình bày không?'), findsOneWidget);
      expect(find.text('Offline (fallback)'), findsOneWidget);
      expect(find.textContaining('Standard ·'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Share'));
      await settle(tester);
      expect(
        system.shared,
        startsWith(
          'Client meeting\n\nBạn có thể trình bày không?\nCould you walk us through it?',
        ),
      );

      await tester.tap(find.bySemanticsLabel('Delete'));
      await settle(tester);
      expect(find.text('Delete this session?'), findsOneWidget);
      await tester.tap(find.text('Delete').last);
      await settle(tester);

      expect(await tester.runAsync(() => repo.load(id)), isNull);
      expect(find.textContaining('No sessions yet'), findsOneWidget);
    },
  );

  testWidgets('rename updates the title', (tester) async {
    await tester.runAsync(
      () => seed([('Xin chào', 'Hello', UtteranceEngine.standard)]),
    );
    await pumpHistory(tester);
    await tester.tap(find.text('Hello').first);
    await settle(tester);

    await tester.tap(find.bySemanticsLabel('Rename'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Hotel check-in');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('Hotel check-in'), findsOneWidget);
  });
}

/// Lets database work finish, then rebuilds.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/common/widgets/app_platform_slider.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/settings/app_preferences.dart';
import 'package:lingo_mate/features/listen/data/notifier/listen_notifier.dart';
import 'package:lingo_mate/features/listen/presentation/view/listen_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';

/// Lets the pipeline's real asynchronous work finish, then rebuilds.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  const languages = LanguagePair('en', 'vi');
  late ConversationFakes fakes;
  late FakeSystemSettings system;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    system = FakeSystemSettings();
  });

  tearDown(() => fakes.db.close());

  /// Pumps the Listen page in English.
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        listenClockProvider.overrideWithValue(() => fakes.nowMs),
        systemSettingsProvider.overrideWithValue(system),
        capabilityMatrixProvider.overrideWith((ref) async => bundledMatrix()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
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
          home: const ListenPage(languages: languages),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
    return container;
  }

  /// Speaks one utterance into the open mic.
  Future<void> speak(WidgetTester tester) async {
    fakes.nowMs += 1700;
    fakes.capture
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await settle(tester);
  }

  testWidgets('Start shows captions, translation large and original small '
      '(AC-03.1)', (tester) async {
    fakes.recognizer.texts.add('Good morning everyone');
    await pumpPage(tester);
    expect(
      find.bySemanticsLabel("Speaker's language: English"),
      findsOneWidget,
    );
    expect(
      find.text('Tap Start and hold the phone towards the speaker.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    await speak(tester);
    expect(find.text('[vi] Good morning everyone'), findsOneWidget);
    expect(find.text('Good morning everyone'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('Pause turns the mic off and Resume turns it on (AC-03.6)', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);

    await tester.tap(find.text('Pause'));
    await settle(tester);
    expect(container.read(listenProvider(languages)).listening, isFalse);
    expect(fakes.capture.controller, isNull);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Paused. The microphone is off.'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(container.read(listenProvider(languages)).listening, isTrue);
  });

  testWidgets(
    'scrolling up shows Jump to live, which follows again (AC-03.2)',
    (tester) async {
      fakes.recognizer.texts.addAll([
        for (var i = 0; i < 12; i++) 'Sentence number $i of the lecture',
      ]);
      await pumpPage(tester);
      await tester.tap(find.text('Start'));
      await settle(tester);
      for (var i = 0; i < 12; i++) {
        await speak(tester);
      }
      await tester.pumpAndSettle();
      expect(
        find.text('[vi] Sentence number 11 of the lecture'),
        findsOneWidget,
      );
      expect(find.text('Jump to live'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('Jump to live'), findsOneWidget);
      expect(find.text('[vi] Sentence number 11 of the lecture'), findsNothing);

      await tester.tap(find.text('Jump to live'));
      await tester.pumpAndSettle();
      expect(find.text('Jump to live'), findsNothing);
      expect(
        find.text('[vi] Sentence number 11 of the lecture'),
        findsOneWidget,
      );
    },
  );

  testWidgets('caption size changes at once and is saved (AC-03.5); keep '
      'screen on is applied (AC-03.3)', (tester) async {
    final container = await pumpPage(tester);
    expect(system.screenOn, isTrue);

    await tester.tap(find.bySemanticsLabel('Caption settings'));
    await tester.pumpAndSettle();
    expect(find.text('Medium'), findsOneWidget);

    final slider = tester.widget<AppPlatformSlider>(
      find.byType(AppPlatformSlider),
    );
    slider.onChanged!(3);
    await tester.pumpAndSettle();
    expect(find.text('Extra large'), findsOneWidget);
    expect(
      container.read(appPreferencesProvider).captionSize,
      CaptionSize.extraLarge,
    );
    expect(fakes.prefs.getString('pref_caption_size'), 'extraLarge');

    await tester.tap(find.text('Keep screen on'));
    await tester.pumpAndSettle();
    expect(system.screenOn, isFalse);
    expect(fakes.prefs.getBool('pref_keep_screen_on'), isFalse);
  });

  testWidgets('the speaker language can be changed', (tester) async {
    final container = await pumpPage(tester);
    await tester.tap(find.bySemanticsLabel("Speaker's language: English"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();

    expect(container.read(listenProvider(languages)).source, 'auto');
    expect(find.bySemanticsLabel("Speaker's language: Auto"), findsOneWidget);
  });
}

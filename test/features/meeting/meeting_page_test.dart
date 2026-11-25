import 'package:flutter/services.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/core/background/background_capture.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/features/meeting/data/notifier/meeting_notifier.dart';
import 'package:lingo_mate/features/meeting/data/notifier/meeting_setup_notifier.dart';
import 'package:lingo_mate/features/meeting/presentation/view/meeting_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';
import 'meeting_fakes.dart';

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
  late ConversationFakes fakes;
  late FakeBackground background;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['en'],
      'app_locale': 'en',
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    background = FakeBackground();
  });

  tearDown(() => fakes.db.close());

  /// Pumps the Meeting page in English.
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        meetingClockProvider.overrideWithValue(() => fakes.nowMs),
        backgroundCaptureProvider.overrideWithValue(background),
        notificationPermissionProvider.overrideWithValue(() async {}),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        capabilityMatrixProvider.overrideWith((ref) async => bundledMatrix()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: OverlaySupport.global(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) {
              ScreenUtil.init(
                context,
                designSize: AppConfiguration.mainAppSize,
              );
              return child!;
            },
            home: const MeetingPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      unawaited(container.read(meetingProvider.notifier).stop());
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
    return container;
  }

  /// Speaks [ms] of speech, then [silenceMs] of silence.
  Future<void> speak(
    WidgetTester tester, {
    int ms = 1000,
    int silenceMs = 700,
  }) async {
    fakes.nowMs += ms + silenceMs;
    fakes.capture
      ..add(pcm(ms, amplitude: 4000))
      ..add(pcm(silenceMs));
    await settle(tester);
  }

  testWidgets('the setup card shows until Don\'t show again (AC-04.1)', (
    tester,
  ) async {
    final c = await pumpPage(tester);
    expect(
      find.text('Put your phone next to the laptop speaker'),
      findsOneWidget,
    );
    expect(find.textContaining('Let the others know'), findsOneWidget);

    await tester.ensureVisible(find.text('Don\'t show again'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Don\'t show again'));
    await tester.pumpAndSettle();
    expect(
      find.text('Put your phone next to the laptop speaker'),
      findsNothing,
    );
    expect(c.read(meetingSetupDismissedProvider), isTrue);
    expect(fakes.prefs.getBool('meeting_setup_dismissed'), isTrue);
  });

  testWidgets('with the overlay allowed, Start shows captions and Stop ends '
      'everything (AC-04.3, AC-04.8)', (tester) async {
    fakes.recognizer.texts.addAll([
      'so we can ship by Friday',
      'great',
      'next topic',
    ]);
    await pumpPage(tester);

    await tester.tap(find.text('Start'));
    await settle(tester);
    expect(background.serviceRunning, isTrue);
    expect(background.overlayVisible, isTrue);
    expect(
      find.text('Listening to the meeting… captions appear here.'),
      findsOneWidget,
    );

    await speak(tester);
    await speak(tester, silenceMs: 3500);
    await speak(tester);
    expect(find.text('[vi] so we can ship by Friday'), findsOneWidget);
    expect(find.text('New speaker'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await settle(tester);
    expect(background.serviceRunning, isFalse);
    expect(background.overlayVisible, isFalse);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('[vi] so we can ship by Friday'), findsOneWidget);
  });

  testWidgets('Suggest reply copies the tapped reply (AC-19.1, AC-19.2)', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    fakes.recognizer.texts.add('so we can ship by Friday');
    await pumpPage(tester);
    expect(find.bySemanticsLabel('Suggest reply'), findsNothing);

    await tester.tap(find.text('Start'));
    await settle(tester);
    await speak(tester);

    await tester.tap(find.bySemanticsLabel('Suggest reply'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('Tap a reply to copy it.'), findsOneWidget);
    expect(fakes.learning.lastReplyLang, 'en');

    await tester.tap(find.text('Could you say that again?'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(copied, ['Could you say that again?']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('without the overlay permission, Meeting runs in the app only '
      'and says so (AC-04.2)', (tester) async {
    background.overlayAllowed = false;
    await pumpPage(tester);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Show captions over other apps'), findsOneWidget);
    await tester.tap(find.text('Captions in the app only'));
    await settle(tester);

    expect(background.serviceRunning, isTrue);
    expect(background.overlayVisible, isFalse);
    expect(
      find.text('Floating captions are off: captions show in this app only.'),
      findsOneWidget,
    );
  });

  testWidgets('Open settings leads to the overlay setting and uses it once '
      'granted', (tester) async {
    background.overlayAllowed = false;
    await pumpPage(tester);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(background.overlaySettingsOpened, 1);

    background.overlayAllowed = true;
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(background.overlayVisible, isTrue);
    expect(find.textContaining('captions show in this app only'), findsNothing);
  });

  testWidgets('long-pressing a line saves it to the phrasebook', (
    tester,
  ) async {
    fakes.recognizer.texts.add('hello team');
    await pumpPage(tester);
    await tester.tap(find.text('Start'));
    await settle(tester);
    await speak(tester);
    await tester.longPress(find.text('[vi] hello team'));
    await settle(tester);

    expect(find.text('Saved to phrasebook'), findsOneWidget);
    final phrases = await tester.runAsync(
      () => fakes.db.select(fakes.db.phrases).get(),
    );
    expect(phrases!.single.targetText, '[vi] hello team');
    await tester.pump(const Duration(seconds: 4));
  });
}

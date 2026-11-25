import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/features/conversation/data/model/conversation_models.dart';
import 'package:lingo_mate/features/conversation/data/notifier/conversation_notifier.dart';
import 'package:lingo_mate/features/conversation/presentation/view/conversation_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import 'conversation_fakes.dart';

void main() {
  const pair = LanguagePair('vi', 'en');
  late ConversationFakes fakes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
  });

  /// Pumps the conversation page with English strings and screen scaling.
  Future<ProviderContainer> pumpPage(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: fakes.overrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            ScreenUtil.init(context, designSize: AppConfiguration.mainAppSize);
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: const ConversationPage(pair: pair),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Lets the pipeline's real asynchronous work finish, then rebuilds.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  testWidgets('partner half is turned 180° and labelled in B (AC-02.1)', (
    tester,
  ) async {
    await pumpPage(tester, locale: const Locale('vi'));

    final rotated = find.byType(RotatedBox);
    expect(tester.widget<RotatedBox>(rotated).quarterTurns, 2);
    expect(
      find.descendant(of: rotated, matching: find.text('ENGLISH')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rotated, matching: find.text('Tap to speak')),
      findsOneWidget,
    );
    expect(find.text('TIẾNG VIỆT'), findsOneWidget);
    expect(find.text('Chạm để nói'), findsOneWidget);
    expect(find.text('Tiêu chuẩn'), findsOneWidget);
  });

  testWidgets('shows the translation on the partner half (AC-02.2)', (
    tester,
  ) async {
    fakes.recognizer.texts.add('Xin chào');
    await pumpPage(tester);

    await tester.tap(find.bySemanticsLabel('Microphone for Vietnamese'));
    await settle(tester);
    expect(find.text('Listening…'), findsOneWidget);

    fakes.nowMs += 1000;
    fakes.capture
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));

    final rotated = find.byType(RotatedBox);
    expect(
      find.descendant(of: rotated, matching: find.text('[en] Xin chào')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rotated, matching: find.text('Xin chào')),
      findsOneWidget,
    );
  });

  testWidgets('switching engine shows a toast (AC-02.7)', (tester) async {
    final container = await pumpPage(tester);

    container
        .read(fakeSelectionProvider.notifier)
        .set(
          const EngineSelection(
            engine: EngineKind.offline,
            blocked: {EngineKind.standard: EngineBlock.noInternet},
          ),
        );
    await tester.pump();
    await tester.pump();

    expect(find.text('Switched to Offline'), findsOneWidget);
    expect(find.text('Offline'), findsWidgets);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Switched to Offline'), findsNothing);
  });

  testWidgets(
    'no engine shows the paused banner with Download packs (AC-02.8)',
    (tester) async {
      fakes.recognizer.texts.add('Xin chào');
      final container = await pumpPage(tester);
      container
          .read(fakeSelectionProvider.notifier)
          .set(
            const EngineSelection(
              engine: null,
              blocked: {
                EngineKind.standard: EngineBlock.noInternet,
                EngineKind.offline: EngineBlock.packsMissing,
              },
            ),
          );
      await tester.pump();

      await container
          .read(conversationProvider(pair).notifier)
          .toggleMic(Speaker.a);
      fakes.nowMs += 1000;
      fakes.capture
        ..add(pcm(1000, amplitude: 4000))
        ..add(pcm(700));
      await settle(tester);
      await tester.pump();

      expect(find.textContaining('Translation is paused'), findsOneWidget);
      expect(find.text('Download packs'), findsOneWidget);
      expect(find.text('Xin chào'), findsOneWidget);
    },
  );

  testWidgets('engine sheet lists reasons and pins the choice (AC-05.7)', (
    tester,
  ) async {
    final container = await pumpPage(tester);
    container
        .read(fakeSelectionProvider.notifier)
        .set(
          const EngineSelection(
            engine: EngineKind.standard,
            blocked: {EngineKind.offline: EngineBlock.packsMissing},
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();

    expect(find.text('Translation engine'), findsOneWidget);
    expect(find.text('Download the offline packs first'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);

    await tester.tap(find.text('In use'));
    await tester.pumpAndSettle();
    expect(container.read(enginePinProvider), EngineKind.standard);
  });

  testWidgets('speaker button turns spoken translations off', (tester) async {
    final container = await pumpPage(tester);

    await tester.tap(find.bySemanticsLabel('Speak translations aloud'));
    await tester.pump();

    expect(container.read(conversationProvider(pair)).speakOn, isFalse);
    expect(
      find.bySemanticsLabel('Translations are not spoken'),
      findsOneWidget,
    );
  });

  testWidgets('lays out at 200% text without overflow', (tester) async {
    fakes.recognizer.texts.add('Xin chào, cho tôi một bàn cho hai người');
    final container = await pumpPage(tester, textScale: 2);
    container
        .read(fakeSelectionProvider.notifier)
        .set(
          const EngineSelection(
            engine: null,
            blocked: {
              EngineKind.standard: EngineBlock.noInternet,
              EngineKind.offline: EngineBlock.packsMissing,
            },
          ),
        );
    await container
        .read(conversationProvider(pair).notifier)
        .toggleMic(Speaker.a);
    fakes.nowMs += 1000;
    fakes.capture
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await settle(tester);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-detect pill turns auto mode on with a hint', (
    tester,
  ) async {
    final container = await pumpPage(tester);

    await tester.tap(find.text('Auto-detect'));
    await settle(tester);

    expect(container.read(conversationProvider(pair)).auto, isTrue);
    expect(find.textContaining('Auto-detect is on'), findsOneWidget);
    expect(find.text('Listening…'), findsNWidgets(2));
  });

  testWidgets('long press offers line actions and copies (AC-02.6)', (
    tester,
  ) async {
    fakes.recognizer.texts.add('Xin chào');
    final container = await pumpPage(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
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
    await container
        .read(conversationProvider(pair).notifier)
        .toggleMic(Speaker.a);
    fakes.nowMs += 1000;
    fakes.capture
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await settle(tester);
    await tester.pump();

    await tester.longPress(find.text('[en] Xin chào'));
    await tester.pumpAndSettle();
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Show large'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump();
    expect(copied, '[en] Xin chào');
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}

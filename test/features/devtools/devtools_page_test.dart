import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/core/audio/audio_capture.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/engines/asr/asr_models.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/features/devtools/data/notifier/devtools_notifier.dart';
import 'package:lingo_mate/features/devtools/data/notifier/devtools_providers.dart';
import 'package:lingo_mate/features/devtools/data/repository/benchmark_files.dart';
import 'package:lingo_mate/features/devtools/presentation/view/devtools_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:lingo_mate/navigation/route_const.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/audio/audio_test_utils.dart';

/// Capture that streams whatever the test pushes.
class _FakeCapture implements AudioCapture {
  _FakeCapture({this.permitted = true});

  final bool permitted;
  final controller = StreamController<Uint8List>.broadcast();
  AudioCaptureConfig? lastConfig;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async {
    lastConfig = config;
    return controller.stream;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  late Directory dir;
  late _FakeCapture capture;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('devtools');
    addTearDown(() => dir.delete(recursive: true));
    capture = _FakeCapture();
  });

  /// Overrides the device-bound providers with fakes.
  List<Override> overrides() => [
    audioCaptureProvider.overrideWithValue(capture),
    remoteConfigProvider.overrideWithValue(
      RemoteConfigService.withDefaults(CrashReporter.disabled()),
    ),
    benchmarkFilesProvider.overrideWith((ref) => BenchmarkFiles(dir)),
    asrModelCatalogProvider.overrideWith(
      (ref) async => const AsrModelCatalog(),
    ),
    benchmarkPipelinesProvider.overrideWith((ref) async => const []),
  ];

  /// Pumps the devtools page with English strings and screen scaling.
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    final container = ProviderContainer(overrides: overrides());
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
          home: const DevtoolsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Lets the mic test's real asynchronous work finish, then rebuilds.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every devtools section', (tester) async {
    await pumpPage(tester);

    expect(find.text('Devtools'), findsOneWidget);
    expect(find.text('Engine'), findsOneWidget);
    expect(find.text('Audio input'), findsOneWidget);
    expect(find.text('Open offline packs'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Remote Config'), 200);
    expect(find.text('Benchmark'), findsOneWidget);
    expect(find.text('0 clips · 0 pipelines'), findsOneWidget);
    expect(
      find.text('No speech model found in the models folder.'),
      findsOneWidget,
    );
    expect(find.text('VAD: energy threshold'), findsOneWidget);
    expect(
      find.textContaining('model_text_translate: gemini-2.5-flash-lite'),
      findsOneWidget,
    );
  });

  testWidgets('engine switcher forces and clears an engine', (tester) async {
    final container = await pumpPage(tester);

    await tester.tap(find.text('Offline'));
    await tester.pump();
    expect(container.read(devtoolsProvider).forcedEngine, EngineKind.offline);

    await tester.tap(find.text('Auto'));
    await tester.pump();
    expect(container.read(devtoolsProvider).forcedEngine, isNull);
  });

  testWidgets('mic test shows segments heard from the mic', (tester) async {
    final container = await pumpPage(tester);

    await tester.ensureVisible(find.text('Start mic test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start mic test'));
    await settle(tester);
    expect(find.text('Stop mic test'), findsOneWidget);

    capture.controller
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await settle(tester);

    expect(find.text('Segment 1: 1000 ms, 100% speech'), findsOneWidget);
    expect(container.read(latencyLogProvider), hasLength(1));
    await tester.tap(find.text('Stop mic test'));
    await settle(tester);
  });

  testWidgets('raw mic switch opens the meeting source', (tester) async {
    await pumpPage(tester);

    await tester.ensureVisible(find.text('Start mic test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start mic test'));
    await settle(tester);
    expect(capture.lastConfig?.source, CaptureSource.voiceRecognition);

    final rawMic = find.descendant(
      of: find.ancestor(
        of: find.text('Raw mic (meeting source)'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(rawMic);
    await tester.pumpAndSettle();
    await tester.tap(rawMic);
    await settle(tester);

    expect(capture.lastConfig?.source, CaptureSource.mic);
    await tester.tap(find.text('Stop mic test'));
    await settle(tester);
  });

  testWidgets('says so when the microphone permission is denied', (
    tester,
  ) async {
    capture = _FakeCapture(permitted: false);
    await pumpPage(tester);

    await tester.ensureVisible(find.text('Start mic test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start mic test'));
    await settle(tester);

    expect(find.text('Microphone permission was denied.'), findsOneWidget);
    expect(find.text('Start mic test'), findsOneWidget);
  });

  test('the router has no devtools route without DEVTOOLS_ENABLED', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(goRouterProvider);
    final names = router.configuration.routes.whereType<GoRoute>().map(
      (r) => r.name,
    );

    expect(names, isNot(contains(AppRouteName.devtools)));
  });
}

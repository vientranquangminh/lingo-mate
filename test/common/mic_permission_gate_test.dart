import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/common/widgets/mic_permission_gate.dart';
import 'package:lingo_mate/core/platform/mic_permission.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_platform.dart';

void main() {
  late FakeMicPermission mic;
  late FakeSystemSettings system;
  late SharedPreferences prefs;
  bool? result;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mic = FakeMicPermission(current: MicPermissionStatus.denied);
    system = FakeSystemSettings();
    result = null;
  });

  /// Pumps a button that runs the gate.
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        micPermissionProvider.overrideWithValue(mic),
        systemSettingsProvider.overrideWithValue(system),
        sharedPreferencesProvider.overrideWithValue(prefs),
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      result = await ensureMicAccess(context, ref),
                  child: const Text('start'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('already granted goes straight through', (tester) async {
    mic.current = MicPermissionStatus.granted;
    await pump(tester);

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(mic.requests, 0);
  });

  testWidgets('explains before the system prompt and asks on Allow (AC-01.6)', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    expect(find.text('Lingo Mate needs the microphone'), findsOneWidget);
    expect(find.textContaining('nothing is recorded'), findsOneWidget);
    expect(mic.requests, 0);

    await tester.tap(find.text('Allow microphone'));
    await tester.pumpAndSettle();

    expect(mic.requests, 1);
    expect(result, isTrue);
  });

  testWidgets('Not now asks nothing', (tester) async {
    await pump(tester);

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(mic.requests, 0);
    expect(result, isFalse);
  });

  testWidgets('after two refusals offers Open settings (AC-01.7)', (
    tester,
  ) async {
    mic.answer = MicPermissionStatus.denied;
    final container = await pump(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow microphone'));
      await tester.pumpAndSettle();
    }
    expect(container.read(userSettingsProvider).micDenials, 2);

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Microphone is off'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(system.appSettingsOpened, 1);
    expect(mic.requests, 2);
    expect(result, isFalse);
  });

  testWidgets('a permanent refusal goes straight to Open settings', (
    tester,
  ) async {
    mic.current = MicPermissionStatus.permanentlyDenied;
    await pump(tester);

    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();

    expect(find.text('Microphone is off'), findsOneWidget);
    expect(mic.requests, 0);
  });
}

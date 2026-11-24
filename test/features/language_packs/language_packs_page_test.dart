import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/resources/app_config.dart';
import 'package:lingo_mate/features/language_packs/data/model/pack_models.dart';
import 'package:lingo_mate/features/language_packs/data/notifier/language_packs_notifier.dart';
import 'package:lingo_mate/features/language_packs/presentation/view/language_packs_page.dart';
import 'package:lingo_mate/generated/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language_packs_fakes.dart';

void main() {
  late FakeTranslationModels translation;
  late FakeSpeechModelFiles speech;
  late FakeWifiState wifi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    translation = FakeTranslationModels();
    speech = FakeSpeechModelFiles();
    wifi = FakeWifiState();
  });

  /// Pumps the packs page with English strings and screen scaling.
  Future<ProviderContainer> pumpPage(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: packOverrides(
        translation: translation,
        speech: speech,
        voices: FakeVoiceChecker(),
        wifi: wifi,
      ),
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
          home: const LanguagePacksPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('groups downloaded and other languages', (tester) async {
    translation.downloaded.addAll({'en', 'vi'});
    speech.files.add('whisper-small.bin');
    await pumpPage(tester);

    expect(find.text('Offline packs'), findsOneWidget);
    expect(find.text('YOUR LANGUAGES'), findsOneWidget);
    expect(find.text('OTHER LANGUAGES'), findsOneWidget);
    expect(find.text('Vietnamese · Tiếng Việt'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(2));
    expect(find.text('Japanese · 日本語'), findsOneWidget);
    expect(find.text('Download'), findsWidgets);
  });

  testWidgets('download asks about mobile data off Wi-Fi', (tester) async {
    wifi.onWifi = false;
    final container = await pumpPage(tester);

    await tester.tap(find.text('Download').first);
    await tester.pumpAndSettle();
    expect(find.text("You're on mobile data"), findsOneWidget);

    await tester.tap(find.text('Wait for Wi-Fi'));
    await tester.pumpAndSettle();
    final waiting = container
        .read(languagePacksProvider)
        .packs
        .where((p) => p.status == PackStatus.waitingForWifi);
    expect(waiting, hasLength(1));
  });

  testWidgets('long press asks before deleting a pack', (tester) async {
    translation.downloaded.addAll({'en', 'ja'});
    final container = await pumpPage(tester);

    await tester.longPress(find.text('Japanese · 日本語'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(translation.downloaded, isNot(contains('ja')));
    expect(
      container.read(languagePacksProvider).pack('ja')!.status,
      PackStatus.notDownloaded,
    );
  });
}

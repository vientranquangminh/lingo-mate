import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/gen/fonts.gen.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/conversation/conversation_fakes.dart';
import '../features/language_packs/language_packs_fakes.dart';
import '../features/phrasebook/phrasebook_test.dart' show settle;
import '../helpers/fake_platform.dart';

/// One screen of the golden suite: where it lives and whether onboarding is finished.
class _Screen {
  const _Screen(this.name, this.location, {this.onboarded = true, this.extra});

  final String name;
  final String location;
  final bool onboarded;
  final Object? extra;
}

/// The seeded session and phrase ids, filled per test.
String _sessionId = '';
String _phraseId = '';

final _screens = <_Screen Function()>[
  () => const _Screen('welcome', '/welcome', onboarded: false),
  () => const _Screen('setup', '/setup', onboarded: false),
  () => const _Screen('home', '/'),
  () => const _Screen('conversation', '/conversation?a=vi&b=en'),
  () => const _Screen('listen', '/listen?from=en&to=vi'),
  () => const _Screen('phrases_mine', '/phrases'),
  () => const _Screen('phrases_quick', '/phrases?tab=quick'),
  () => const _Screen('situation', '/phrases/quick/restaurant'),
  () => const _Screen('add_phrase', '/phrases/new'),
  () => _Screen('phrase_detail', '/phrases/$_phraseId'),
  () => const _Screen('history', '/history'),
  () => _Screen('transcript', '/history/$_sessionId'),
  () => const _Screen('me', '/me'),
  () => const _Screen('translation_voice', '/me/translation'),
  () => const _Screen('privacy', '/me/privacy'),
  () => const _Screen('language_packs', '/language-packs'),
  () => const _Screen(
    'show_mode',
    '/show',
    extra: <String, String?>{
      'text': 'Could we have the bill, please?',
      'original': 'Cho chúng tôi xin hoá đơn.',
      'lang': 'en',
    },
  ),
];

/// Loads Be Vietnam Pro so goldens show real text widths.
Future<void> _loadFonts() async {
  final loader = FontLoader(FontFamily.beVietnamPro);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$weight.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Saves a finished conversation and a phrase with fixed dates.
Future<void> _seed(ConversationFakes fakes) async {
  final sessions = SessionRepository(
    fakes.db,
    now: () => DateTime(2026, 3, 14, 9, 30),
  );
  _sessionId = await sessions.start(
    mode: SessionMode.conversation,
    engine: EngineKind.standard,
    pair: const LanguagePair('vi', 'en'),
  );
  const lines = [
    ('Cho tôi xem thực đơn được không?', 'Could I see the menu, please?'),
    ('Of course, here you are.', 'Dạ được, của anh đây ạ.'),
  ];
  var t = 0;
  for (final (source, target) in lines) {
    await sessions.addUtterance(
      _sessionId,
      NewUtterance(
        speaker: t.isEven ? 'a' : 'b',
        sourceLang: t.isEven ? 'vi' : 'en',
        sourceText: source,
        targetLang: t.isEven ? 'en' : 'vi',
        targetText: target,
        startMs: t * 4000,
        endMs: t * 4000 + 3000,
        engine: UtteranceEngine.standard,
      ),
    );
    t++;
  }
  await sessions.finish(_sessionId);
  final saved =
      await PhraseRepository(
        fakes.db,
        now: () => DateTime(2026, 3, 14, 9, 30),
      ).save(
        sourceLang: 'vi',
        sourceText: 'Cho tôi xin hoá đơn.',
        targetLang: 'en',
        targetText: 'Could we have the bill, please?',
      );
  _phraseId = saved.id;
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in ['en', 'vi']) {
    for (final scale in [1.0, 2.0]) {
      for (final build in _screens) {
        final name = build().name;
        testWidgets(
          '$name renders in $locale at ${scale}x without overflow (AC-11.2)',
          (tester) async {
            final screen = build();
            SharedPreferences.setMockInitialValues({
              'onboarding_done': screen.onboarded,
              'app_locale': locale,
              'my_language': 'vi',
              'partner_languages': ['en'],
            });
            final fakes = ConversationFakes()
              ..prefs = await SharedPreferences.getInstance();
            addTearDown(fakes.db.close);
            FlavorConfig(appFlavor: Flavor.production);
            await tester.runAsync(() => _seed(fakes));
            final target = build();

            tester.view
              ..physicalSize = const Size(375, 812)
              ..devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            final translation = FakeTranslationModels()
              ..downloaded.addAll(['vi', 'en']);
            final container = ProviderContainer(
              overrides: [
                ...packOverrides(
                  translation: translation,
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
              UncontrolledProviderScope(
                container: container,
                child: const MyApp(),
              ),
            );
            await settle(tester);
            container
                .read(goRouterProvider)
                .go(target.location, extra: target.extra);
            await settle(tester);

            if (Platform.isLinux) {
              await expectLater(
                find.byType(MyApp),
                matchesGoldenFile('goldens/$name.$locale.${scale}x.png'),
              );
            }

            await tester.pumpWidget(const SizedBox());
            await settle(tester);
          },
        );
      }
    }
  }
}

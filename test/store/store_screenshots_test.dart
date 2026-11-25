import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/gen/colors.gen.dart';
import 'package:lingo_mate/gen/fonts.gen.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/audio/audio_test_utils.dart';
import '../features/conversation/conversation_fakes.dart';
import '../features/language_packs/language_packs_fakes.dart';
import '../helpers/fake_platform.dart';

/// Whether this run writes the store images; off in normal test runs and CI.
const _enabled = bool.fromEnvironment('STORE_SCREENSHOTS');

/// Store screenshots at 1080 × 2340 in `docs/store/screenshots/{locale}/` and the feature graphic.
void main() {
  setUpAll(_loadFonts);

  testWidgets('feature graphic', skip: !_enabled, (tester) async {
    tester.view
      ..physicalSize = const Size(1024, 500)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final icon = File('assets/brand/play_store_icon.svg').readAsStringSync();
    await tester.pumpWidget(_FeatureGraphic(icon: icon));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    await expectLater(
      find.byType(_FeatureGraphic),
      matchesGoldenFile('../../docs/store/feature-graphic.png'),
    );
  });

  for (final locale in ['en', 'vi']) {
    final copy = _Copy.of(locale);
    for (final shot in _shots) {
      testWidgets('${shot.name} ($locale)', skip: !_enabled, (tester) async {
        SharedPreferences.setMockInitialValues({
          'onboarding_done': true,
          'app_locale': locale,
          'my_language': copy.mine,
          'partner_languages': [copy.partner],
        });
        final fakes = ConversationFakes()
          ..prefs = await SharedPreferences.getInstance();
        addTearDown(fakes.db.close);
        FlavorConfig(appFlavor: Flavor.production);
        final ids = await tester.runAsync(() => _seed(fakes, copy));

        tester.view
          ..physicalSize = const Size(1080, 2340)
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final translation = FakeTranslationModels()
          ..downloaded.addAll(['vi', 'en', 'ja']);
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
          UncontrolledProviderScope(container: container, child: const MyApp()),
        );
        await _settle(tester);
        await shot.open(tester, container, fakes, copy, ids!);
        await _settle(tester);

        await expectLater(
          find.byType(MyApp),
          matchesGoldenFile(
            '../../docs/store/screenshots/$locale/${shot.name}.png',
          ),
        );

        await tester.pumpWidget(const SizedBox());
        await _settle(tester);
      });
    }
  }
}

/// One screenshot: its file name and how to reach the screen.
class _Shot {
  const _Shot(this.name, this.open);

  final String name;
  final Future<void> Function(
    WidgetTester tester,
    ProviderContainer container,
    ConversationFakes fakes,
    _Copy copy,
    _Ids ids,
  )
  open;
}

/// Ids of the seeded rows.
class _Ids {
  const _Ids({required this.meeting});

  final String meeting;
}

final _shots = <_Shot>[
  _Shot('01-conversation', (tester, container, fakes, copy, ids) async {
    fakes.recognizer.texts.add(copy.said);
    fakes.standard.scripted[copy.said] = copy.saidTranslated;
    container
        .read(goRouterProvider)
        .go('/conversation?a=${copy.mine}&b=${copy.partner}');
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel(copy.myMic));
    await _settle(tester);
    fakes.nowMs += 1000;
    fakes.capture
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));
  }),
  _Shot('02-home', (tester, container, fakes, copy, ids) async {
    container.read(goRouterProvider).go('/');
  }),
  _Shot('03-meeting-summary', (tester, container, fakes, copy, ids) async {
    container.read(goRouterProvider).go('/history/${ids.meeting}');
  }),
  _Shot('04-phrasebook', (tester, container, fakes, copy, ids) async {
    container.read(goRouterProvider).go('/phrases');
  }),
  _Shot('05-quick-phrases', (tester, container, fakes, copy, ids) async {
    container.read(goRouterProvider).go('/phrases/quick/restaurant');
  }),
  _Shot('06-review', (tester, container, fakes, copy, ids) async {
    container.read(goRouterProvider).go('/phrases/review');
    await _settle(tester);
    await tester.tap(find.text(copy.showAnswer));
  }),
  _Shot('07-offline-packs', (tester, container, fakes, copy, ids) async {
    container.read(goRouterProvider).go('/language-packs');
  }),
];

/// Seed text per UI language: the user speaks [mine] with a [partner] speaker.
class _Copy {
  const _Copy({
    required this.mine,
    required this.partner,
    required this.myMic,
    required this.said,
    required this.saidTranslated,
    required this.showAnswer,
    required this.meetingTitle,
    required this.summary,
    required this.keyTerms,
    required this.actions,
    required this.phrases,
    required this.meetingLines,
  });

  final String mine;
  final String partner;
  final String myMic;
  final String said;
  final String saidTranslated;
  final String showAnswer;
  final String meetingTitle;
  final String summary;
  final List<String> keyTerms;
  final List<String> actions;
  final List<(String, String)> phrases;
  final List<(String, String)> meetingLines;

  /// The copy for UI language [locale].
  static _Copy of(String locale) => locale == 'vi' ? _vi : _en;

  static const _vi = _Copy(
    mine: 'vi',
    partner: 'en',
    myMic: 'Micro cho Tiếng Việt',
    said: 'Cho tôi hỏi ga tàu gần nhất ở đâu?',
    saidTranslated: 'Excuse me, where is the nearest train station?',
    showAnswer: 'Xem đáp án',
    meetingTitle: 'Họp tiến độ với khách hàng',
    summary:
        'Khách hàng đồng ý dời ngày phát hành sang thứ Sáu tuần sau. Nhóm sẽ '
        'sửa lỗi webhook trước, sau đó gửi bản thử để khách kiểm tra.',
    keyTerms: ['webhook: cơ chế báo sự kiện', 'staging: môi trường thử'],
    actions: [
      'Minh sửa lỗi webhook trước thứ Tư',
      'Gửi bản thử lên staging vào thứ Năm',
    ],
    phrases: [
      ('Hãy đặt mục tiêu giao vào thứ Sáu.', "Let's aim to ship by Friday."),
      (
        'Chuyện gì xảy ra nếu webhook bị lỗi?',
        'What happens if the webhook fails?',
      ),
      ('Cho tôi xin hoá đơn.', 'Could we have the bill, please?'),
      (
        'Bạn nói chậm lại một chút được không?',
        'Could you speak a little slower?',
      ),
    ],
    meetingLines: [
      (
        'So we can ship by Friday next week.',
        'Vậy ta có thể phát hành vào thứ Sáu tuần sau.',
      ),
      ('First we need to fix the webhook.', 'Trước tiên cần sửa webhook.'),
    ],
  );

  static const _en = _Copy(
    mine: 'en',
    partner: 'vi',
    myMic: 'Microphone for English',
    said: 'Where is the nearest train station?',
    saidTranslated: 'Ga tàu gần nhất ở đâu ạ?',
    showAnswer: 'Show answer',
    meetingTitle: 'Client progress meeting',
    summary:
        'The client agreed to move the release to next Friday. The team will '
        'fix the webhook issue first, then share a test build for review.',
    keyTerms: ['webhook', 'staging build'],
    actions: [
      'Minh fixes the webhook by Wednesday',
      'Share the staging build on Thursday',
    ],
    phrases: [
      ("Let's aim to ship by Friday.", 'Hãy đặt mục tiêu giao vào thứ Sáu.'),
      (
        'What happens if the webhook fails?',
        'Chuyện gì xảy ra nếu webhook bị lỗi?',
      ),
      ('Could we have the bill, please?', 'Cho tôi xin hoá đơn.'),
      (
        'Could you speak a little slower?',
        'Bạn nói chậm lại một chút được không?',
      ),
    ],
    meetingLines: [
      (
        'Vậy ta có thể phát hành vào thứ Sáu tuần sau.',
        'So we can ship by Friday next week.',
      ),
      ('Trước tiên cần sửa webhook.', 'First we need to fix the webhook.'),
    ],
  );
}

/// Saves phrases and a summarised meeting with fixed dates.
Future<_Ids> _seed(ConversationFakes fakes, _Copy copy) async {
  final at = DateTime(2026, 11, 24, 15, 30);
  final phrases = PhraseRepository(fakes.db, now: () => at);
  for (final (source, target) in copy.phrases) {
    await phrases.save(
      sourceLang: copy.mine,
      sourceText: source,
      targetLang: copy.partner,
      targetText: target,
    );
  }
  final sessions = SessionRepository(fakes.db, now: () => at);
  final meeting = await sessions.start(
    mode: SessionMode.meeting,
    engine: EngineKind.standard,
    pair: LanguagePair(copy.partner, copy.mine),
  );
  var t = 0;
  for (final (source, target) in copy.meetingLines) {
    await sessions.addUtterance(
      meeting,
      NewUtterance(
        speaker: null,
        sourceLang: copy.partner,
        sourceText: source,
        targetLang: copy.mine,
        targetText: target,
        startMs: t * 5000,
        endMs: t * 5000 + 4000,
        engine: UtteranceEngine.standard,
      ),
    );
    t++;
  }
  await sessions.finish(meeting);
  await sessions.rename(meeting, copy.meetingTitle);
  final recap =
      '{"lang":"${copy.mine}","summary":"${copy.summary}",'
      '"keyTerms":[${copy.keyTerms.map((k) => '"$k"').join(',')}],'
      '"actionItems":[${copy.actions.map((a) => '"$a"').join(',')}]}';
  await (fakes.db.update(
    fakes.db.sessions,
  )..where((s) => s.id.equals(meeting))).write(
    SessionsCompanion(durationSec: const Value(1860), summary: Value(recap)),
  );
  return _Ids(meeting: meeting);
}

/// Loads Be Vietnam Pro so the screenshots show real text.
Future<void> _loadFonts() async {
  final loader = FontLoader(FontFamily.beVietnamPro);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$weight.ttf')
        .readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Lets real asynchronous work finish, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// The 1024 × 500 Play feature graphic: icon, name and tagline on the brand colour.
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic({required this.icon});

  final String icon;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: ColorName.cyanMermaidHarbour,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 72),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(56),
                child: SvgPicture.string(icon, width: 260, height: 260),
              ),
              const SizedBox(width: 56),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lingo Mate',
                      style: TextStyle(
                        fontFamily: FontFamily.beVietnamPro,
                        fontWeight: FontWeight.w700,
                        fontSize: 64,
                        color: ColorName.orangeUnbleached,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Talk, listen and meet across languages. Even offline.',
                      style: TextStyle(
                        fontFamily: FontFamily.beVietnamPro,
                        fontWeight: FontWeight.w500,
                        fontSize: 30,
                        height: 1.3,
                        color: ColorName.orangeUnbleached,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

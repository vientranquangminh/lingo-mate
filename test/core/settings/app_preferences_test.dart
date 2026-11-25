import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/analytics/analytics_service.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/engines/tts/speech_synthesizer.dart';
import 'package:lingo_mate/core/licenses/app_licenses.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/core/settings/app_preferences.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/conversation/conversation_fakes.dart';

/// Records the events it is asked to send.
class _FakeSink implements AnalyticsSink {
  final events = <String>[];
  bool? collection;

  @override
  Future<void> log(String name, Map<String, Object> parameters) async =>
      events.add(name);

  @override
  Future<void> setCollectionEnabled(bool enabled) async => collection = enabled;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Builds a container on the mock preferences.
  ProviderContainer build() {
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('defaults: Auto, Live allowed, normal voice, medium captions, screen on, consent on', () {
    expect(build().read(appPreferencesProvider), const AppPreferences());
  });

  test('choices are saved and read back after a restart', () async {
    final notifier = build().read(appPreferencesProvider.notifier);
    await notifier.setEngine(EnginePreference.preferOffline);
    await notifier.setAllowLive(false);
    await notifier.setVoiceSpeed(VoiceSpeed.slow);
    await notifier.setCaptionSize(CaptionSize.large);
    await notifier.setKeepScreenOn(false);
    await notifier.setAnalytics(false);
    await notifier.setCrashReports(false);

    expect(
      build().read(appPreferencesProvider),
      const AppPreferences(
        engine: EnginePreference.preferOffline,
        allowLive: false,
        voiceSpeed: VoiceSpeed.slow,
        captionSize: CaptionSize.large,
        keepScreenOn: false,
        analytics: false,
        crashReports: false,
      ),
    );
  });

  test('Prefer Offline puts Offline first (AC-10.2)', () {
    expect(EnginePreference.preferOffline.order.first, EngineKind.offline);
    expect(EnginePreference.auto.order.first, EngineKind.standard);
    expect(EnginePreference.preferStandard.order.first, EngineKind.standard);
  });

  test('the voice speed scales every spoken line', () async {
    final inner = FakeSynthesizer();
    var speed = VoiceSpeed.slow;
    final tts = RatedSpeechSynthesizer(inner, rate: () => speed.rate);
    final rates = <double>[];
    final recording = RatedSpeechSynthesizer(
      _RateRecorder(rates),
      rate: () => speed.rate,
    );

    await tts.speak('Hello', lang: 'en');
    await recording.speak('Hello', lang: 'en');
    speed = VoiceSpeed.fast;
    await recording.speak('Hello', lang: 'en', rate: 2);

    expect(inner.spoken, [('Hello', 'en')]);
    expect(rates, [0.75, 2.5]);
  });

  test('no analytics event is sent while consent is off (AC-10.4)', () async {
    final sink = _FakeSink();
    final analytics = AnalyticsService(sink: sink);

    await analytics.setEnabled(false);
    await analytics.phraseSaved(source: 'quick');
    await analytics.sessionStart(
      mode: 'conversation',
      engine: 'standard',
      pair: 'vi-en',
    );
    expect(sink.events, isEmpty);
    expect(sink.collection, isFalse);

    await analytics.setEnabled(true);
    await analytics.phraseSaved(source: 'quick');
    expect(sink.events, ['phrase_saved']);
    expect(sink.collection, isTrue);
  });

  test('the consent setting drives the analytics service', () async {
    final sink = _FakeSink();
    final analytics = AnalyticsService(sink: sink);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        analyticsProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(c.dispose);
    c.listen(privacyConsentProvider, (_, _) {});
    expect(analytics.enabled, isTrue);

    await c.read(appPreferencesProvider.notifier).setAnalytics(false);
    c.read(privacyConsentProvider);

    expect(analytics.enabled, isFalse);
  });

  test('licenses list ML Kit (AC-10.5)', () async {
    registerAppLicenses();

    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }

    expect(packages, containsAll(['Google ML Kit', 'sherpa-onnx']));
  });

  test('wipe empties every table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final sessions = SessionRepository(db);
    final id = await sessions.start(
      mode: SessionMode.conversation,
      engine: EngineKind.standard,
      pair: const LanguagePair('vi', 'en'),
    );
    await sessions.addUtterance(
      id,
      const NewUtterance(
        speaker: 'a',
        sourceLang: 'vi',
        sourceText: 'Xin chào',
        targetLang: 'en',
        targetText: 'Hello',
        startMs: 0,
        endMs: 1,
        engine: UtteranceEngine.standard,
      ),
    );
    final phrases = PhraseRepository(db);
    final saved = await phrases.save(
      sourceLang: 'vi',
      sourceText: 'Cảm ơn',
      targetLang: 'en',
      targetText: 'Thank you',
    );
    await phrases.addTag(saved.id, 'Travel');

    await db.wipe();

    for (final table in db.allTables) {
      expect(
        await db.select(table).get(),
        isEmpty,
        reason: table.actualTableName,
      );
    }
    expect(
      await phrases.watch(const PhraseFilter(query: 'cam on')).first,
      isEmpty,
    );
  });
}

/// Records the rate of each spoken line.
class _RateRecorder extends FakeSynthesizer {
  _RateRecorder(this.rates);

  final List<double> rates;

  @override
  Future<void> speak(String text, {required String lang, double rate = 1.0}) {
    rates.add(rate);
    return super.speak(text, lang: lang, rate: rate);
  }
}

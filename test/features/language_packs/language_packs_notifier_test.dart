import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/features/language_packs/data/model/pack_models.dart';
import 'package:lingo_mate/features/language_packs/data/notifier/language_packs_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language_packs_fakes.dart';

void main() {
  late FakeTranslationModels translation;
  late FakeSpeechModelFiles speech;
  late FakeVoiceChecker voices;
  late FakeWifiState wifi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    translation = FakeTranslationModels();
    speech = FakeSpeechModelFiles();
    voices = FakeVoiceChecker();
    wifi = FakeWifiState();
  });

  /// Builds a container and waits for the first load.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(
      overrides: packOverrides(
        translation: translation,
        speech: speech,
        voices: voices,
        wifi: wifi,
      ),
    );
    addTearDown(c.dispose);
    c.listen(languagePacksProvider, (_, _) {});
    await c.read(languagePacksProvider.notifier).load();
    return c;
  }

  LanguagePack pack(ProviderContainer c, String lang) =>
      c.read(languagePacksProvider).pack(lang)!;

  test('loads every matrix language with its device status', () async {
    translation.downloaded.addAll({'en', 'vi'});
    speech.files.add('whisper-small.bin');
    final c = await build();
    final state = c.read(languagePacksProvider);

    expect(state.loading, isFalse);
    expect(state.packs, hasLength(10));
    expect(state.wifiOnly, isTrue);
    expect(pack(c, 'vi').status, PackStatus.ready);
    expect(pack(c, 'ja').status, PackStatus.notDownloaded);
    expect(pack(c, 'en').status, PackStatus.ready);
  });

  test('download fetches the English pivot with the pack (AC-06.5)', () async {
    final c = await build();

    await c.read(languagePacksProvider.notifier).download('vi');

    expect(translation.downloads, containsAll(['en', 'vi']));
    expect(pack(c, 'vi').status, PackStatus.ready);
    expect(pack(c, 'en').translation, ComponentStatus.ready);
    expect(translation.wifiRequired, everyElement(isTrue));
  });

  test('shows speech progress while the model downloads', () async {
    speech.pending = Completer<void>();
    final c = await build();

    final done = c.read(languagePacksProvider.notifier).download('ko');
    await pumpEventQueue();
    speech.progress!(0.4);

    expect(pack(c, 'ko').status, PackStatus.downloading);
    expect(pack(c, 'ko').speechProgress, 0.4);

    speech.pending!.complete();
    await done;
    expect(pack(c, 'ko').status, PackStatus.ready);
  });

  test('marks a failed download for retry', () async {
    translation.fail = true;
    final c = await build();

    await c.read(languagePacksProvider.notifier).download('ja');

    expect(pack(c, 'ja').status, PackStatus.failed);
  });

  test('flags a missing voice after download', () async {
    final c = await build();

    await c.read(languagePacksProvider.notifier).download('ja');

    expect(pack(c, 'ja').voiceMissing, isTrue);
  });

  test(
    'asks before using mobile data, then waits for Wi-Fi (AC-06.2)',
    () async {
      wifi.onWifi = false;
      final c = await build();
      final notifier = c.read(languagePacksProvider.notifier);

      await notifier.download('vi');
      expect(c.read(languagePacksProvider).askMobileDataFor, 'vi');
      expect(translation.downloads, isEmpty);

      await notifier.answerMobileData(useMobileData: false);
      expect(c.read(languagePacksProvider).askMobileDataFor, isNull);
      expect(pack(c, 'vi').status, PackStatus.waitingForWifi);

      wifi.connect();
      await pumpEventQueue();
      expect(pack(c, 'vi').status, PackStatus.ready);
    },
  );

  test('downloads over mobile data when the user agrees', () async {
    wifi.onWifi = false;
    final c = await build();
    final notifier = c.read(languagePacksProvider.notifier);

    await notifier.download('vi');
    await notifier.answerMobileData(useMobileData: true);

    expect(pack(c, 'vi').status, PackStatus.ready);
    expect(translation.wifiRequired, everyElement(isFalse));
  });

  test('turning Wi-Fi-only off skips the question and is saved', () async {
    wifi.onWifi = false;
    final c = await build();
    final notifier = c.read(languagePacksProvider.notifier);

    await notifier.setWifiOnly(false);
    await notifier.download('vi');

    expect(c.read(languagePacksProvider).askMobileDataFor, isNull);
    expect(pack(c, 'vi').status, PackStatus.ready);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('packs_wifi_only'), isFalse);
  });

  test('delete keeps a speech file another pack uses (AC-06.6)', () async {
    translation.downloaded.addAll({'en', 'vi', 'ko'});
    speech.files.addAll({'whisper-small.bin', 'whisper-ko.bin'});
    final c = await build();

    await c.read(languagePacksProvider.notifier).delete('vi');

    expect(pack(c, 'vi').status, PackStatus.notDownloaded);
    expect(speech.deleted, isEmpty);
    expect(translation.downloaded, isNot(contains('vi')));

    await c.read(languagePacksProvider.notifier).delete('ko');
    expect(speech.deleted, ['whisper-ko.bin']);
  });

  test('English stays while another pack needs it as the pivot', () async {
    translation.downloaded.addAll({'en', 'vi'});
    final c = await build();
    final notifier = c.read(languagePacksProvider.notifier);

    expect(notifier.canDelete('en'), isFalse);
    await notifier.delete('en');
    expect(translation.downloaded, contains('en'));

    await notifier.delete('vi');
    expect(notifier.canDelete('en'), isTrue);
  });
}

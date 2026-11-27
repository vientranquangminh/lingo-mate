import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/engines/asr/asr_models.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../model/pack_models.dart';
import '../repository/pack_repository.dart';
import '../state/language_packs_state.dart';

/// ML Kit translation models.
final translationModelsProvider = Provider<TranslationModels>(
  (ref) => MlKitTranslationModels(),
);

/// Speech model files.
final speechModelFilesProvider = Provider<SpeechModelFiles>(
  (ref) => HttpSpeechModelFiles(),
);

/// Text-to-speech voice check.
final voiceCheckerProvider = Provider<VoiceChecker>((ref) => TtsVoiceChecker());

/// Wi-Fi state.
final wifiStateProvider = Provider<WifiState>((ref) => ConnectivityWifiState());

/// Whether speech models pushed to `models/` exist; used while Remote Config names no download.
final pushedSpeechModelsProvider = FutureProvider<bool>(
  (ref) async => !(await (await AsrModelStore.open()).scan()).isEmpty,
);

/// Language packs; kept alive so downloads continue when the screen closes (AC-06.3).
final languagePacksProvider =
    NotifierProvider<LanguagePacksNotifier, LanguagePacksState>(
      LanguagePacksNotifier.new,
    );

/// Loads pack status, downloads and deletes packs, and keeps English as the ML Kit pivot (AC-06.5).
class LanguagePacksNotifier extends Notifier<LanguagePacksState> {
  static const _wifiOnlyKey = 'packs_wifi_only';
  static const pivot = 'en';

  StreamSubscription<void>? _wifiSubscription;

  @override
  LanguagePacksState build() {
    ref.onDispose(() => _wifiSubscription?.cancel());
    Future.microtask(load);
    return const LanguagePacksState();
  }

  /// Reads every pack's status from the device.
  Future<void> load() async {
    final matrix = await ref.read(capabilityMatrixProvider.future);
    final specs = ref.read(engineRemoteConfigProvider).asrModels;
    final translation = ref.read(translationModelsProvider);
    final speechFiles = ref.read(speechModelFilesProvider);
    final voices = ref.read(voiceCheckerProvider);
    final pushed = await ref
        .read(pushedSpeechModelsProvider.future)
        .catchError((Object _) => false);
    final prefs = await SharedPreferences.getInstance();
    final packs = <LanguagePack>[];
    for (final language in matrix.languages.values) {
      final offline = language.offlineTranslate && language.asrOnDevice.usable;
      final spec = AsrModelSpec.fromJson(specs[language.code]);
      final translationReady =
          offline && await translation.isDownloaded(language.code);
      final speechReady =
          offline && (spec == null ? pushed : await speechFiles.exists(spec));
      packs.add(
        LanguagePack(
          lang: language.code,
          offlineSupported: offline,
          speechSpec: spec,
          translation: translationReady
              ? ComponentStatus.ready
              : ComponentStatus.missing,
          speech: speechReady ? ComponentStatus.ready : ComponentStatus.missing,
          voiceMissing:
              translationReady && !await voices.hasVoice(language.code),
        ),
      );
    }
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loading: false,
      packs: packs,
      wifiOnly: prefs.getBool(_wifiOnlyKey) ?? true,
    );
  }

  /// Turns the Wi-Fi-only setting on or off.
  Future<void> setWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
    state = state.copyWith(wifiOnly: value);
  }

  /// Starts downloading [lang], asking first when Wi-Fi-only is on and the phone is on mobile data (AC-06.2).
  Future<void> download(String lang) async {
    if (state.wifiOnly && !await ref.read(wifiStateProvider).isOnWifi()) {
      state = state.copyWith(askMobileDataFor: () => lang);
      return;
    }
    await _download(lang, allowMobileData: !state.wifiOnly);
  }

  /// Answers the mobile data question: download now, or wait for Wi-Fi.
  Future<void> answerMobileData({required bool useMobileData}) async {
    final lang = state.askMobileDataFor;
    state = state.copyWith(askMobileDataFor: () => null);
    if (lang == null) {
      return;
    }
    if (useMobileData) {
      await _download(lang, allowMobileData: true);
      return;
    }
    _update(
      lang,
      (p) => p.copyWith(
        translation: p.translation == ComponentStatus.ready
            ? null
            : ComponentStatus.waitingForWifi,
        speech: p.speech == ComponentStatus.ready
            ? null
            : ComponentStatus.waitingForWifi,
      ),
    );
    _wifiSubscription ??= ref
        .read(wifiStateProvider)
        .wifiConnected
        .listen((_) => _resumeWaiting());
  }

  /// Removes [lang]'s models after the user confirmed (AC-06.6); English stays while other packs need it.
  Future<void> delete(String lang) async {
    final pack = state.pack(lang);
    if (pack == null || !canDelete(lang)) {
      return;
    }
    await ref.read(translationModelsProvider).delete(lang);
    final spec = pack.speechSpec;
    final sharedByOthers = state.packs.any(
      (p) =>
          p.lang != lang &&
          p.speech == ComponentStatus.ready &&
          p.speechSpec?.fileName == spec?.fileName,
    );
    if (spec != null && !sharedByOthers) {
      await ref.read(speechModelFilesProvider).delete(spec);
    }
    _update(
      lang,
      (p) => p.copyWith(
        translation: ComponentStatus.missing,
        speech: spec == null ? null : ComponentStatus.missing,
        speechProgress: 0,
        voiceMissing: false,
      ),
    );
    ref
      ..invalidate(packsInstalledProvider)
      ..invalidate(asrModelCatalogProvider);
  }

  /// Removes every downloaded translation and speech model, English last.
  Future<void> deleteAll() async {
    if (state.loading) {
      await load();
    }
    final translation = ref.read(translationModelsProvider);
    final speech = ref.read(speechModelFilesProvider);
    final langs = [
      for (final p in state.packs)
        if (p.lang != pivot) p.lang,
      pivot,
    ];
    for (final lang in langs) {
      await translation.delete(lang).catchError((Object _) => false);
    }
    final specs = {
      for (final p in state.packs)
        if (p.speechSpec != null) p.speechSpec!.fileName: p.speechSpec!,
    };
    for (final spec in specs.values) {
      await speech.delete(spec).catchError((Object _) {});
    }
    ref
      ..invalidate(packsInstalledProvider)
      ..invalidate(asrModelCatalogProvider)
      ..invalidateSelf();
  }

  /// Whether [lang] may be deleted: English only once no other language has a translation model.
  bool canDelete(String lang) {
    if (lang != pivot) {
      return true;
    }
    return !state.packs.any(
      (p) => p.lang != pivot && p.translation == ComponentStatus.ready,
    );
  }

  /// Downloads the ML Kit model (plus the English pivot) and the speech model of [lang].
  Future<void> _download(String lang, {required bool allowMobileData}) async {
    final pack = state.pack(lang);
    if (pack == null || !pack.offlineSupported) {
      return;
    }
    final langs = [if (lang != pivot) pivot, lang];
    await Future.wait([
      for (final l in langs) _downloadTranslation(l, allowMobileData),
      _downloadSpeech(lang),
    ]);
    await _downloadSpeakerModel();
    ref
      ..invalidate(packsInstalledProvider)
      ..invalidate(asrModelCatalogProvider);
    final voice = await ref.read(voiceCheckerProvider).hasVoice(lang);
    _update(lang, (p) => p.copyWith(voiceMissing: !voice));
  }

  /// Downloads one ML Kit model unless it is already there.
  Future<void> _downloadTranslation(String lang, bool allowMobileData) async {
    final pack = state.pack(lang);
    if (pack == null || pack.translation == ComponentStatus.ready) {
      return;
    }
    _update(lang, (p) => p.copyWith(translation: ComponentStatus.downloading));
    final ok = await ref
        .read(translationModelsProvider)
        .download(lang, wifiRequired: !allowMobileData)
        .catchError((Object _) => false);
    _update(
      lang,
      (p) => p.copyWith(
        translation: ok ? ComponentStatus.ready : ComponentStatus.failed,
      ),
    );
  }

  /// Downloads the speech model with progress, when Remote Config names one.
  Future<void> _downloadSpeech(String lang) async {
    final spec = state.pack(lang)?.speechSpec;
    if (spec == null || state.pack(lang)!.speech == ComponentStatus.ready) {
      return;
    }
    _update(
      lang,
      (p) => p.copyWith(speech: ComponentStatus.downloading, speechProgress: 0),
    );
    try {
      await ref
          .read(speechModelFilesProvider)
          .download(
            spec,
            (progress) =>
                _update(lang, (p) => p.copyWith(speechProgress: progress)),
          );
      _update(lang, (p) => p.copyWith(speech: ComponentStatus.ready));
    } catch (_) {
      _update(lang, (p) => p.copyWith(speech: ComponentStatus.failed));
    }
  }

  /// Downloads the speaker model that tells meeting speakers apart, once, alongside the first speech pack; failures are ignored.
  Future<void> _downloadSpeakerModel() async {
    final spec = AsrModelSpec.fromJson(
      ref.read(engineRemoteConfigProvider).speakerModel,
    );
    final files = ref.read(speechModelFilesProvider);
    if (spec == null ||
        await files.exists(spec).catchError((Object _) => true)) {
      return;
    }
    await files.download(spec, (_) {}).catchError((Object _) {});
  }

  /// Starts every pack that was waiting for Wi-Fi.
  void _resumeWaiting() {
    for (final pack in state.packs) {
      if (pack.status == PackStatus.waitingForWifi) {
        unawaited(_download(pack.lang, allowMobileData: false));
      }
    }
  }

  /// Replaces [lang]'s pack with [change] applied.
  void _update(String lang, LanguagePack Function(LanguagePack) change) {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      packs: [for (final p in state.packs) p.lang == lang ? change(p) : p],
    );
  }
}

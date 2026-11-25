import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/generative_model_factory.dart';
import '../audio/audio_capture.dart';
import '../audio/pcm_player.dart';
import '../audio/silero_voice_activity_detector.dart';
import '../audio/voice_activity_detector.dart';
import '../config/feature_switches.dart';
import '../di/di.dart';
import '../../gen/assets.gen.dart';
import '../glossary/glossary_repository.dart';
import '../glossary/glossary_translator.dart';
import '../settings/app_preferences.dart';
import 'asr/asr_models.dart';
import 'asr/sherpa_whisper_engine.dart';
import 'asr/whisper_cpp_engine.dart';
import 'engines.dart';
import 'live/live_models.dart';
import 'live/live_session.dart';
import 'translate/gemini_text_translator.dart';
import 'translate/mlkit_text_translator.dart';
import 'tts/speech_synthesizer.dart';

/// Microphone capture.
final audioCaptureProvider = Provider<AudioCapture>(
  (ref) => getIt<AudioCapture>(),
);

/// Speech models found in the app's `models/` folder, after copying the bundled Silero VAD there.
final asrModelCatalogProvider = FutureProvider<AsrModelCatalog>((ref) async {
  final store = await AsrModelStore.open();
  await store
      .installFile(sileroVadFile, () async {
        final data = await rootBundle.load(Assets.models.sileroVad);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      })
      .catchError((Object _) => '');
  return store.scan();
});

/// File name of the Silero VAD model bundled with the app and copied next to the speech models.
const sileroVadFile = 'silero_vad.onnx';

/// Standard engine translator (Gemini through Firebase AI Logic).
final geminiTranslatorProvider = Provider<TextTranslatorEngine>(
  (ref) => GlossaryTranslator(
    GeminiTextTranslator.firebase(getIt<GenerativeModelFactory>()),
    ref.watch(featureSwitchesProvider.select((s) => s.glossary))
        ? ref.watch(glossaryRepositoryProvider).termsIn
        : (_) async => const {},
  ),
);

/// Offline engine translator (ML Kit).
final mlKitTranslatorProvider = Provider<MlKitTextTranslator>((ref) {
  final translator = MlKitTextTranslator();
  ref.onDispose(translator.close);
  return translator;
});

/// Translator for [EngineKind.offline] or [EngineKind.standard].
final textTranslatorProvider =
    Provider.family<TextTranslatorEngine, EngineKind>(
      (ref, kind) => kind == EngineKind.offline
          ? ref.watch(mlKitTranslatorProvider)
          : ref.watch(geminiTranslatorProvider),
    );

/// Creates the VAD: Silero when its model is present, the energy detector otherwise.
final vadFactoryProvider = FutureProvider<VoiceActivityDetector Function()>((
  ref,
) async {
  final silero = (await ref.watch(asrModelCatalogProvider.future)).sileroVad;
  if (silero == null) {
    return EnergyVoiceActivityDetector.new;
  }
  return () {
    try {
      return SileroVoiceActivityDetector(silero);
    } catch (_) {
      return EnergyVoiceActivityDetector();
    }
  };
});

/// On-device speech recognizer for the modes: the first sherpa-onnx Whisper model, else whisper.cpp; null when no model is installed.
final speechRecognizerProvider = FutureProvider<SpeechRecognizerEngine?>((
  ref,
) async {
  final catalog = await ref.watch(asrModelCatalogProvider.future);
  final sherpa = catalog.sherpaWhisper.firstOrNull;
  if (sherpa != null) {
    return SherpaWhisperEngine(sherpa);
  }
  final cpp = catalog.whisperCpp.firstOrNull;
  return cpp == null ? null : WhisperCppEngine(cpp);
});

/// Text-to-speech for spoken translations.
final speechSynthesizerProvider = Provider<SpeechSynthesizerEngine>((ref) {
  final tts = FlutterTtsSynthesizer();
  ref.onDispose(tts.dispose);
  return RatedSpeechSynthesizer(
    tts,
    rate: () => ref.read(appPreferencesProvider).voiceSpeed.rate,
  );
});

/// Opens Live Translate sessions.
final liveSessionOpenerProvider =
    Provider<LiveSession Function(LiveSessionConfig)>((ref) => LiveSession.new);

/// Plays Live translated speech.
final livePlayerProvider = Provider<PcmPlayer>(
  (ref) => const NativePcmPlayer(),
);

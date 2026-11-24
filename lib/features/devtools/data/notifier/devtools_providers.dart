import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_capture.dart';
import '../../../../core/audio/silero_voice_activity_detector.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/asr/asr_models.dart';
import '../../../../core/engines/asr/sherpa_whisper_engine.dart';
import '../../../../core/engines/asr/whisper_cpp_engine.dart';
import '../../../../core/config/remote_config_service.dart';
import '../../../../core/di/di.dart';
import '../model/benchmark_models.dart';
import '../repository/benchmark_files.dart';

/// Microphone used by the mic test.
final audioCaptureProvider = Provider<AudioCapture>(
  (ref) => getIt<AudioCapture>(),
);

/// Remote Config values shown in the viewer.
final remoteConfigProvider = Provider<RemoteConfigService>(
  (ref) => getIt<RemoteConfigService>(),
);

/// Speech models found in the app's `models/` folder.
final asrModelCatalogProvider = FutureProvider<AsrModelCatalog>(
  (ref) async => (await AsrModelStore.open()).scan(),
);

/// Pipelines the benchmark can run: one per speech model found.
final benchmarkPipelinesProvider = FutureProvider<List<BenchmarkPipeline>>((
  ref,
) async {
  final catalog = await ref.watch(asrModelCatalogProvider.future);
  return [
    for (final m in catalog.sherpaWhisper)
      BenchmarkPipeline(asr: SherpaWhisperEngine(m)),
    for (final m in catalog.whisperCpp)
      BenchmarkPipeline(asr: WhisperCppEngine(m)),
  ];
});

/// Creates the VAD: Silero when its model is present, the energy detector otherwise.
final vadFactoryProvider = FutureProvider<VoiceActivityDetector Function()>((
  ref,
) async {
  final silero = (await ref.watch(asrModelCatalogProvider.future)).sileroVad;
  if (silero == null) {
    return EnergyVoiceActivityDetector.new;
  }
  return () => SileroVoiceActivityDetector(silero);
});

/// Folder holding benchmark clips and results.
final benchmarkFilesProvider = FutureProvider<BenchmarkFiles>(
  (ref) => BenchmarkFiles.open(),
);

/// Recent per-utterance stage timings shown by the latency HUD.
final latencyLogProvider =
    NotifierProvider<LatencyLogNotifier, List<Map<String, int?>>>(
      LatencyLogNotifier.new,
    );

/// Keeps the last few latency rows.
class LatencyLogNotifier extends Notifier<List<Map<String, int?>>> {
  static const maxRows = 5;

  @override
  List<Map<String, int?>> build() => const [];

  /// Adds one utterance's stage timings, dropping the oldest beyond [maxRows].
  void add(Map<String, int?> row) {
    final rows = [...state, row];
    state = rows.length > maxRows ? rows.sublist(rows.length - maxRows) : rows;
  }
}

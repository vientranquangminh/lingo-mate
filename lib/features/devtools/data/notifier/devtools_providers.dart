import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/remote_config_service.dart';
import '../../../../core/di/di.dart';
import '../../../../core/engines/asr/sherpa_whisper_engine.dart';
import '../../../../core/engines/asr/whisper_cpp_engine.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/engines.dart';
import '../model/benchmark_models.dart';
import '../repository/benchmark_files.dart';

export '../../../../core/engines/engine_instances.dart';

/// Remote Config values shown in the viewer.
final remoteConfigProvider = Provider<RemoteConfigService>(
  (ref) => getIt<RemoteConfigService>(),
);

/// Pipelines the benchmark can run: each speech model alone, then followed by Gemini (Standard) and ML Kit (Offline).
final benchmarkPipelinesProvider = FutureProvider<List<BenchmarkPipeline>>((
  ref,
) async {
  final catalog = await ref.watch(asrModelCatalogProvider.future);
  final translators = [
    ref.watch(geminiTranslatorProvider),
    ref.watch(mlKitTranslatorProvider),
  ];
  final engines = <SpeechRecognizerEngine>[
    for (final m in catalog.sherpaWhisper) SherpaWhisperEngine(m),
    for (final m in catalog.whisperCpp) WhisperCppEngine(m),
  ];
  return [
    for (final asr in engines) ...[
      BenchmarkPipeline(asr: asr),
      for (final t in translators) BenchmarkPipeline(asr: asr, translator: t),
    ],
  ];
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

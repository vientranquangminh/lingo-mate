import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_capture.dart';
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

/// Pipelines the benchmark can run; speech recognition engines are added in T-0.4.
final benchmarkPipelinesProvider = Provider<List<BenchmarkPipeline>>(
  (ref) => const [],
);

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

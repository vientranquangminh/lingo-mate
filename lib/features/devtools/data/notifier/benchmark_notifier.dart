import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/benchmark_models.dart';
import '../repository/benchmark_runner.dart';
import '../state/devtools_state.dart';
import 'devtools_providers.dart';

/// Benchmark clips, pipelines and the latest run.
final benchmarkProvider = NotifierProvider<BenchmarkNotifier, BenchmarkState>(
  BenchmarkNotifier.new,
);

/// Loads benchmark clips and runs every clip through every pipeline.
class BenchmarkNotifier extends Notifier<BenchmarkState> {
  List<BenchmarkClip> _clips = const [];

  @override
  BenchmarkState build() => const BenchmarkState();

  /// Reads the manifest from the benchmark folder.
  Future<void> loadClips() async {
    state = state.copyWith(status: BenchmarkStatus.loading, error: '');
    try {
      final files = await ref.read(benchmarkFilesProvider.future);
      _clips = await files.readManifest();
      ref.invalidate(asrModelCatalogProvider);
      final pipelines = await ref.read(benchmarkPipelinesProvider.future);
      state = state.copyWith(
        status: BenchmarkStatus.idle,
        folder: files.directory.path,
        clipCount: _clips.length,
        pipelineCount: pipelines.length,
      );
    } catch (e) {
      state = state.copyWith(status: BenchmarkStatus.failed, error: '$e');
    }
  }

  /// Runs all clips through all pipelines in real time and writes a CSV.
  Future<void> run() async {
    final pipelines = await ref.read(benchmarkPipelinesProvider.future);
    if (_clips.isEmpty || pipelines.isEmpty) {
      return;
    }
    final clock = Stopwatch()..start();
    final runner = BenchmarkRunner(
      nowMs: () => clock.elapsedMilliseconds,
      vadFactory: await ref.read(vadFactoryProvider.future),
    );
    final rows = <BenchmarkRow>[];
    try {
      final files = await ref.read(benchmarkFilesProvider.future);
      for (final clip in _clips) {
        final pcm = await files.readPcm(clip);
        for (final pipeline in pipelines) {
          state = state.copyWith(
            status: BenchmarkStatus.running,
            currentClip: clip.id,
            currentPipeline: pipeline.id,
          );
          rows.addAll(
            await runner.runClip(clip: clip, pcm: pcm, pipeline: pipeline),
          );
        }
      }
      final csv = await files.writeCsv(rows, DateTime.now());
      state = state.copyWith(
        status: BenchmarkStatus.done,
        rowCount: rows.length,
        csvPath: csv.path,
      );
    } catch (e) {
      state = state.copyWith(status: BenchmarkStatus.failed, error: '$e');
    }
  }
}

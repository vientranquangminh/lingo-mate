import 'package:equatable/equatable.dart';

import '../../../../core/audio/audio_capture.dart';
import '../../../../core/engines/engines.dart';

/// A segment heard during the mic test.
class MicSegment extends Equatable {
  const MicSegment({required this.durationMs, required this.speechRatio});

  final int durationMs;
  final double speechRatio;

  @override
  List<Object?> get props => [durationMs, speechRatio];
}

/// Devtools switches and the live mic test.
class DevtoolsState extends Equatable {
  const DevtoolsState({
    this.forcedEngine,
    this.latencyHudVisible = false,
    this.forceRegionBlock = false,
    this.captureConfig = const AudioCaptureConfig(),
    this.micRunning = false,
    this.micDenied = false,
    this.micLevelDbfs,
    this.micSegments = const [],
  });

  final EngineKind? forcedEngine;
  final bool latencyHudVisible;
  final bool forceRegionBlock;
  final AudioCaptureConfig captureConfig;
  final bool micRunning;
  final bool micDenied;
  final double? micLevelDbfs;
  final List<MicSegment> micSegments;

  DevtoolsState copyWith({
    EngineKind? Function()? forcedEngine,
    bool? latencyHudVisible,
    bool? forceRegionBlock,
    AudioCaptureConfig? captureConfig,
    bool? micRunning,
    bool? micDenied,
    double? Function()? micLevelDbfs,
    List<MicSegment>? micSegments,
  }) {
    return DevtoolsState(
      forcedEngine: forcedEngine != null ? forcedEngine() : this.forcedEngine,
      latencyHudVisible: latencyHudVisible ?? this.latencyHudVisible,
      forceRegionBlock: forceRegionBlock ?? this.forceRegionBlock,
      captureConfig: captureConfig ?? this.captureConfig,
      micRunning: micRunning ?? this.micRunning,
      micDenied: micDenied ?? this.micDenied,
      micLevelDbfs: micLevelDbfs != null ? micLevelDbfs() : this.micLevelDbfs,
      micSegments: micSegments ?? this.micSegments,
    );
  }

  @override
  List<Object?> get props => [
    forcedEngine,
    latencyHudVisible,
    forceRegionBlock,
    captureConfig.source,
    captureConfig.noiseSuppression,
    captureConfig.autoGain,
    micRunning,
    micDenied,
    micLevelDbfs,
    micSegments,
  ];
}

/// Progress of a benchmark run.
enum BenchmarkStatus { idle, loading, running, done, failed }

/// Benchmark clips, pipelines and the latest run.
class BenchmarkState extends Equatable {
  const BenchmarkState({
    this.status = BenchmarkStatus.idle,
    this.folder = '',
    this.clipCount = 0,
    this.pipelineCount = 0,
    this.currentClip = '',
    this.currentPipeline = '',
    this.rowCount = 0,
    this.csvPath = '',
    this.error = '',
  });

  final BenchmarkStatus status;
  final String folder;
  final int clipCount;
  final int pipelineCount;
  final String currentClip;
  final String currentPipeline;
  final int rowCount;
  final String csvPath;
  final String error;

  BenchmarkState copyWith({
    BenchmarkStatus? status,
    String? folder,
    int? clipCount,
    int? pipelineCount,
    String? currentClip,
    String? currentPipeline,
    int? rowCount,
    String? csvPath,
    String? error,
  }) {
    return BenchmarkState(
      status: status ?? this.status,
      folder: folder ?? this.folder,
      clipCount: clipCount ?? this.clipCount,
      pipelineCount: pipelineCount ?? this.pipelineCount,
      currentClip: currentClip ?? this.currentClip,
      currentPipeline: currentPipeline ?? this.currentPipeline,
      rowCount: rowCount ?? this.rowCount,
      csvPath: csvPath ?? this.csvPath,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    folder,
    clipCount,
    pipelineCount,
    currentClip,
    currentPipeline,
    rowCount,
    csvPath,
    error,
  ];
}

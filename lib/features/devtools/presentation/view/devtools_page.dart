import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../core/audio/audio_capture.dart';
import '../../../../core/engines/engines.dart';
import '../../../../navigation/route_const.dart';
import '../../data/notifier/benchmark_notifier.dart';
import '../../data/notifier/devtools_notifier.dart';
import '../../data/notifier/devtools_providers.dart';
import '../../data/notifier/live_test_notifier.dart';
import '../../data/notifier/soak_notifier.dart';
import '../../data/state/devtools_state.dart';
import '../widget/devtools_widgets.dart';

/// Devtools screen S-23 (dev flavor only).
class DevtoolsPage extends ConsumerStatefulWidget {
  const DevtoolsPage({super.key});

  @override
  ConsumerState<DevtoolsPage> createState() => _DevtoolsPageState();
}

class _DevtoolsPageState extends ConsumerState<DevtoolsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(benchmarkProvider.notifier).loadClips());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.devtoolsTitle)),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing16.w,
          vertical: AppParams.spacing8.h,
        ),
        children: const [
          _EngineSection(),
          _AudioSection(),
          _LiveSection(),
          _SoakSection(),
          _BenchmarkSection(),
          _RemoteConfigSection(),
        ],
      ),
    );
  }
}

/// Engine switcher, latency HUD and region-block switches.
class _EngineSection extends ConsumerWidget {
  const _EngineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final state = ref.watch(devtoolsProvider);
    final notifier = ref.read(devtoolsProvider.notifier);
    final options = <(EngineKind?, String)>[
      (null, l10n.devtoolsEngineAuto),
      (EngineKind.offline, l10n.devtoolsEngineOffline),
      (EngineKind.standard, l10n.devtoolsEngineStandard),
      (EngineKind.live, l10n.devtoolsEngineLive),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevtoolsSectionTitle(l10n.devtoolsEngineSection),
        Wrap(
          spacing: AppParams.spacing8.w,
          runSpacing: AppParams.spacing8.h,
          children: [
            for (final (engine, label) in options)
              AppPlatformOutlinedButton(
                onPressed: () => notifier.forceEngine(engine),
                text: label,
                backgroundColor: state.forcedEngine == engine
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
              ),
          ],
        ),
        SizedBox(height: AppParams.spacing8.h),
        DevtoolsToggle(
          label: l10n.devtoolsLatencyHud,
          value: state.latencyHudVisible,
          onChanged: notifier.setLatencyHud,
        ),
        DevtoolsToggle(
          label: l10n.devtoolsRegionBlock,
          value: state.forceRegionBlock,
          onChanged: notifier.setForceRegionBlock,
        ),
        SizedBox(height: AppParams.spacing8.h),
        Wrap(
          spacing: AppParams.spacing8.w,
          runSpacing: AppParams.spacing8.h,
          children: [
            AppPlatformOutlinedButton(
              onPressed: () => context.pushNamed(AppRouteName.languagePacks),
              text: l10n.devtoolsOpenPacks,
            ),
            AppPlatformOutlinedButton(
              onPressed: () => context.pushNamed(
                AppRouteName.conversation,
                queryParameters: const {'a': 'vi', 'b': 'en'},
              ),
              text: l10n.devtoolsOpenConversation,
            ),
            AppPlatformOutlinedButton(
              onPressed: () => context.pushNamed(AppRouteName.history),
              text: l10n.devtoolsOpenHistory,
            ),
          ],
        ),
      ],
    );
  }
}

/// Capture settings and the live mic test.
class _AudioSection extends ConsumerWidget {
  const _AudioSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final state = ref.watch(devtoolsProvider);
    final notifier = ref.read(devtoolsProvider.notifier);
    final level = state.micLevelDbfs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevtoolsSectionTitle(l10n.devtoolsAudioSection),
        DevtoolsToggle(
          label: l10n.devtoolsRawMic,
          value: state.captureConfig.source == CaptureSource.mic,
          onChanged: notifier.setRawMic,
        ),
        DevtoolsToggle(
          label: l10n.devtoolsNoiseSuppression,
          value: state.captureConfig.noiseSuppression,
          onChanged: notifier.setNoiseSuppression,
        ),
        DevtoolsToggle(
          label: l10n.devtoolsAutoGain,
          value: state.captureConfig.autoGain,
          onChanged: notifier.setAutoGain,
        ),
        SizedBox(height: AppParams.spacing8.h),
        AppPlatformElevatedButton(
          onPressed: notifier.toggleMic,
          text: state.micRunning ? l10n.devtoolsMicStop : l10n.devtoolsMicStart,
        ),
        if (state.micDenied) DevtoolsText(l10n.devtoolsMicDenied),
        if (level != null)
          DevtoolsText(l10n.devtoolsMicLevel(level.toStringAsFixed(1))),
        for (final (i, segment) in state.micSegments.indexed)
          DevtoolsText(
            l10n.devtoolsSegment(
              i + 1,
              segment.durationMs,
              (segment.speechRatio * 100).round(),
            ),
            small: true,
          ),
      ],
    );
  }
}

/// Live Translate test: one-way or two-way, transcripts and lag.
class _LiveSection extends ConsumerWidget {
  const _LiveSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final state = ref.watch(liveTestProvider);
    final notifier = ref.read(liveTestProvider.notifier);
    final lag = state.medianLagMs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevtoolsSectionTitle(l10n.devtoolsLiveSection),
        DevtoolsToggle(
          label: l10n.devtoolsLiveTwoWay,
          value: state.twoWay,
          onChanged: state.running ? null : notifier.setTwoWay,
        ),
        AppPlatformElevatedButton(
          onPressed: notifier.toggle,
          text: state.running ? l10n.devtoolsLiveStop : l10n.devtoolsLiveStart,
        ),
        if (state.error.isNotEmpty) DevtoolsText(state.error, small: true),
        if (lag != null)
          DevtoolsText(l10n.devtoolsLiveLag(lag, state.lagsMs.length)),
        for (final line in state.lines)
          DevtoolsText(
            '→${line.target}: ${line.input} ⇒ ${line.output}',
            small: true,
          ),
      ],
    );
  }
}

/// Background soak: Meeting capture in the foreground service with the overlay.
class _SoakSection extends ConsumerWidget {
  const _SoakSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final state = ref.watch(soakProvider);
    final notifier = ref.read(soakProvider.notifier);
    final minutes = state.elapsed.inMinutes;
    final seconds = state.elapsed.inSeconds % 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevtoolsSectionTitle(l10n.devtoolsSoakSection),
        AppPlatformElevatedButton(
          onPressed: notifier.toggle,
          text: state.running ? l10n.devtoolsSoakStop : l10n.devtoolsSoakStart,
        ),
        if (state.running || state.elapsed > Duration.zero)
          DevtoolsText(
            l10n.devtoolsSoakStats(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              state.segments,
              state.maxGapMs,
            ),
          ),
        if (state.overlayDenied) ...[
          DevtoolsText(l10n.devtoolsSoakOverlayDenied, small: true),
          AppPlatformOutlinedButton(
            onPressed: notifier.openOverlaySettings,
            text: l10n.devtoolsSoakOverlayGrant,
          ),
        ],
        for (final line in state.savedLines)
          DevtoolsText(l10n.devtoolsSoakSaved(line), small: true),
        if (state.error.isNotEmpty) DevtoolsText(state.error, small: true),
      ],
    );
  }
}

/// Benchmark runner: clip folder, run button and the result.
class _BenchmarkSection extends ConsumerWidget {
  const _BenchmarkSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final state = ref.watch(benchmarkProvider);
    final notifier = ref.read(benchmarkProvider.notifier);
    final busy =
        state.status == BenchmarkStatus.running ||
        state.status == BenchmarkStatus.loading;
    final canRun = !busy && state.clipCount > 0 && state.pipelineCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevtoolsSectionTitle(l10n.devtoolsBenchmarkSection),
        if (state.folder.isNotEmpty)
          DevtoolsText(l10n.devtoolsBenchmarkFolder(state.folder), small: true),
        DevtoolsText(
          l10n.devtoolsBenchmarkSummary(state.clipCount, state.pipelineCount),
        ),
        if (state.pipelineCount == 0)
          DevtoolsText(l10n.devtoolsBenchmarkNoPipelines, small: true),
        ...switch (ref.watch(asrModelCatalogProvider)) {
          AsyncData(:final value) => [
            if (!value.isEmpty)
              DevtoolsText(
                l10n.devtoolsModels(
                  [
                    ...value.sherpaWhisper.map((m) => 'sherpa ${m.name}'),
                    ...value.whisperCpp.map((m) => 'whisper.cpp ${m.name}'),
                  ].join(', '),
                ),
                small: true,
              ),
            DevtoolsText(
              value.sileroVad == null
                  ? l10n.devtoolsVadEnergy
                  : l10n.devtoolsVadSilero,
              small: true,
            ),
          ],
          _ => const <Widget>[],
        },
        SizedBox(height: AppParams.spacing8.h),
        Row(
          children: [
            AppPlatformOutlinedButton(
              onPressed: busy ? null : notifier.loadClips,
              text: l10n.devtoolsBenchmarkReload,
            ),
            SizedBox(width: AppParams.spacing8.w),
            Expanded(
              child: AppPlatformElevatedButton(
                onPressed: canRun ? notifier.run : null,
                loading: state.status == BenchmarkStatus.running,
                text: l10n.devtoolsBenchmarkRun,
              ),
            ),
          ],
        ),
        SizedBox(height: AppParams.spacing8.h),
        AppPlatformOutlinedButton(
          onPressed: state.offlineModels == OfflineModelsStatus.downloading
              ? null
              : notifier.downloadOfflineModels,
          text: l10n.devtoolsOfflineModelsDownload,
        ),
        if (state.offlineModels != OfflineModelsStatus.unknown)
          DevtoolsText(switch (state.offlineModels) {
            OfflineModelsStatus.downloading =>
              l10n.devtoolsOfflineModelsDownloading,
            OfflineModelsStatus.ready => l10n.devtoolsOfflineModelsReady,
            _ => l10n.devtoolsOfflineModelsFailed,
          }, small: true),
        SizedBox(height: AppParams.spacing8.h),
        switch (state.status) {
          BenchmarkStatus.running => DevtoolsText(
            l10n.devtoolsBenchmarkRunning(
              state.currentClip,
              state.currentPipeline,
            ),
          ),
          BenchmarkStatus.done => DevtoolsText(
            l10n.devtoolsBenchmarkDone(state.rowCount, state.csvPath),
          ),
          BenchmarkStatus.failed => DevtoolsText(
            l10n.devtoolsBenchmarkFailed(state.error),
          ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// Current Remote Config values and their source.
class _RemoteConfigSection extends ConsumerWidget {
  const _RemoteConfigSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = ref.watch(remoteConfigProvider).snapshot();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevtoolsSectionTitle(context.localization.devtoolsRemoteConfigSection),
        for (final entry in values.entries)
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppParams.spacing4.h),
            child: DevtoolsText('${entry.key}: ${entry.value}', small: true),
          ),
      ],
    );
  }
}

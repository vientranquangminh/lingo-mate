import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/auth/auth_models.dart';
import '../../../../core/engines/live/live_access.dart';
import '../../../../common/widgets/app_empty_state.dart';
import '../../../../common/widgets/app_motion.dart';
import '../../../../common/widgets/draft_line.dart';
import '../../../../common/widgets/usage_sheet.dart';
import '../../../../common/widgets/require_sign_in.dart';
import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_banner.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../common/widgets/caption_scale.dart';
import '../../../../common/widgets/caption_settings_sheet.dart';
import '../../../../common/widgets/engine_chip.dart';
import '../../../../common/widgets/engine_sheet.dart';
import '../../../../common/widgets/keep_screen_on.dart';
import '../../../../common/widgets/mic_permission_gate.dart';
import '../../../../common/widgets/source_language_pill.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../generated/l10n.dart';
import '../../../../navigation/route_const.dart';
import '../../data/model/listen_models.dart';
import '../../data/notifier/listen_notifier.dart';
import '../../data/state/listen_state.dart';
import '../widget/caption_tile.dart';

/// Listen screen S-06: live captions of a speaker in the user's language, with jump to live, pause and stop (F-03).
class ListenPage extends ConsumerStatefulWidget {
  const ListenPage({super.key, required this.languages, this.media = false});

  final LanguagePair languages;
  final bool media;

  /// The Listen session behind this screen: the mic, or the phone's playback in media mode (F-21).
  NotifierProvider<ListenNotifier, ListenState> get provider =>
      media ? mediaListenProvider(languages) : listenProvider(languages);

  @override
  ConsumerState<ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends ConsumerState<ListenPage> {
  final _scroll = ScrollController();
  bool _follow = true;

  ListenNotifier get _notifier => ref.read(widget.provider.notifier);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Keeps the newest caption in view while following live.
  void _scrollToLive({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(
          end,
          duration: AppParams.standardDuration,
          curve: Curves.easeOut,
        );
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  /// Stops following when the user scrolls up, and follows again at the bottom (AC-03.2).
  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      final metrics = notification.metrics;
      final atLive =
          metrics.pixels >= metrics.maxScrollExtent - AppParams.spacing24.h;
      if (atLive != _follow) {
        setState(() => _follow = atLive);
      }
    }
    return false;
  }

  /// Follows live again.
  void _jumpToLive() {
    setState(() => _follow = true);
    _scrollToLive();
  }

  /// Starts or resumes captions once the microphone is allowed.
  Future<void> _start() async {
    if (!await ensureMicAccess(context, ref) || !mounted) {
      return;
    }
    final live = ref.read(widget.provider).engine == EngineKind.live;
    if (live && !await requireSignIn(context, ref, SignInReason.live)) {
      _notifier.skipLive();
    }
    await _notifier.start();
  }

  /// Ends the session and leaves.
  Future<void> _stop() async {
    await _notifier.pause();
    if (mounted) {
      await Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final state = ref.watch(provider);
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    ref
      ..listen(provider.select((s) => s.captions.length), (previous, next) {
        if (_follow && next > (previous ?? 0)) {
          _scrollToLive();
        }
      })
      ..listen(provider.select((s) => s.draft), (_, next) {
        if (_follow && next != null) {
          _scrollToLive();
        }
      })
      ..listen(provider.select((s) => s.liveStops), (_, _) {
        final denial = ref.read(provider).liveDenial;
        showAppToast(
          context,
          denial == LiveDenial.quota
              ? l10n.liveQuotaFallback
              : l10n.liveUnavailableFallback,
        );
        if (denial == LiveDenial.quota) {
          showUsageSheet(context);
        }
      })
      ..listen(provider.select((s) => s.switchCount), (_, _) {
        final engine = ref.read(provider).switchedTo;
        if (engine != null) {
          showAppToast(
            context,
            l10n.conversationSwitchedTo(_engineName(l10n, engine)),
          );
        }
      });
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: KeepScreenOn(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                languages: widget.languages,
                state: state,
                provider: provider,
                media: widget.media,
              ),
              if (widget.media && !state.started)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppParams.spacing20.w,
                    AppParams.spacing12.h,
                    AppParams.spacing20.w,
                    0,
                  ),
                  child: AppBanner(
                    kind: AppBannerKind.info,
                    message: l10n.mediaIntro,
                  ),
                ),
              if (state.mediaSilent)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppParams.spacing20.w,
                    AppParams.spacing12.h,
                    AppParams.spacing20.w,
                    0,
                  ),
                  child: AppBanner(
                    kind: AppBannerKind.warning,
                    message: l10n.mediaSilent,
                  ),
                ),
              if (state.block != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppParams.spacing20.w,
                    AppParams.spacing12.h,
                    AppParams.spacing20.w,
                    0,
                  ),
                  child: _BlockBanner(block: state.block!),
                ),
              Expanded(
                child: Stack(
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: _Captions(state: state, controller: _scroll),
                    ),
                    if (!_follow && state.captions.isNotEmpty)
                      Positioned(
                        bottom: AppParams.spacing16.h,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AppPlatformElevatedButton(
                            onPressed: _jumpToLive,
                            text: l10n.listenJumpToLive,
                            icon: AppIcon(
                              AppIcons.chevronDown,
                              size: 20,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _BottomBar(
                state: state,
                onStart: _start,
                onPause: _notifier.pause,
                onStop: _stop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the display name of [engine].
  static String _engineName(AppLocalizations l10n, EngineKind engine) =>
      switch (engine) {
        EngineKind.offline => l10n.engineOffline,
        EngineKind.standard => l10n.engineStandard,
        EngineKind.live => l10n.engineLive,
      };
}

/// Back, the source → target pill, the engine chip and caption settings (S-06 header).
class _Header extends ConsumerWidget {
  const _Header({
    required this.languages,
    required this.state,
    required this.provider,
    required this.media,
  });

  final LanguagePair languages;
  final ListenState state;
  final NotifierProvider<ListenNotifier, ListenState> provider;
  final bool media;

  /// Opens the list of speaker languages, Auto first.
  Future<void> _pickSource(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final matrix = await ref.read(capabilityMatrixProvider.future);
    if (!context.mounted) {
      return;
    }
    final notifier = ref.read(provider.notifier);
    await showAppActionSheet(
      context: context,
      title: l10n.listenPickSource,
      cancel: l10n.commonCancel,
      actions: [
        AppSheetAction(
          icon: AppIcons.autoTurn,
          label: l10n.listenAuto,
          onSelected: () => notifier.setSource(listenAutoSource),
        ),
        for (final language in matrix.languages.values)
          if (language.code != state.target)
            AppSheetAction(
              icon: AppIcons.language,
              label: language.name == l10n.languageName(language.code)
                  ? language.name
                  : '${l10n.languageName(language.code)} · ${language.name}',
              onSelected: () => notifier.setSource(language.code),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final auto = state.source == listenAutoSource;
    final sourceLabel = auto ? l10n.listenAuto : state.source.toUpperCase();
    final sourceName = auto ? l10n.listenAuto : l10n.languageName(state.source);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing8.w,
          vertical: AppParams.spacing8.h,
        ),
        child: Row(
          children: [
            AppCircleIconButton(
              icon: AppIcons.back,
              semanticLabel: l10n.conversationBack,
              borderColor: Colors.transparent,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Wrap(
                spacing: AppParams.spacing8.w,
                runSpacing: AppParams.spacing8.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SourceLanguagePill(
                    source: sourceLabel,
                    target: state.target.toUpperCase(),
                    semanticLabel: l10n.listenSourceSemantics(sourceName),
                    onTap: () => _pickSource(context, ref),
                  ),
                  EngineChip(
                    engine: state.engine,
                    onTap: () async {
                      final choice = await showEngineSheet(
                        context: context,
                        current: state.engine,
                        pinned: ref.read(enginePinProvider),
                        blocked: state.blocked,
                      );
                      if (choice != null) {
                        ref.read(enginePinProvider.notifier).pin(choice.engine);
                      }
                    },
                  ),
                ],
              ),
            ),
            AppCircleIconButton(
              icon: AppIcons.textSize,
              semanticLabel: l10n.listenCaptionSettings,
              borderColor: Colors.transparent,
              onPressed: () => showCaptionSettingsSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The caption list, or a hint before the first caption.
class _Captions extends StatelessWidget {
  const _Captions({required this.state, required this.controller});

  final ListenState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final draft = state.draft;
    if (state.captions.isEmpty && draft == null) {
      final hint = !state.started
          ? l10n.listenIdle
          : state.listening
          ? l10n.listenWaiting
          : l10n.listenPausedNote;
      return AppEmptyState(
        icon: !state.started
            ? AppIcons.modeListen
            : state.listening
            ? AppIcons.waveform
            : AppIcons.pause,
        message: hint,
      );
    }
    return CaptionScale(
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.symmetric(vertical: AppParams.spacing8.h),
        itemCount:
            state.captions.length +
            (draft != null ? 1 : 0) +
            (state.paused ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.captions.length && draft != null) {
            return AppFadeSlideIn(child: DraftLine(text: draft));
          }
          if (index >= state.captions.length) {
            return Padding(
              padding: EdgeInsets.all(AppParams.spacing20.r),
              child: Text(
                l10n.listenPausedNote,
                style: context.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final caption = state.captions[index];
          return AppFadeSlideIn(
            key: ValueKey(caption.id),
            child: CaptionTile(caption: caption),
          );
        },
      ),
    );
  }
}

/// Start before the session; Pause or Resume and Stop during it (S-06 bottom bar).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  final ListenState state;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing20.w,
          vertical: AppParams.spacing12.h,
        ),
        child: !state.started
            ? AppPlatformElevatedButton(
                onPressed: onStart,
                text: l10n.listenStart,
                icon: AppIcon(AppIcons.mic, size: 20, color: scheme.onPrimary),
              )
            : Row(
                children: [
                  Expanded(
                    child: AppPlatformElevatedButton(
                      onPressed: state.listening ? onPause : onStart,
                      text: state.listening
                          ? l10n.listenPause
                          : l10n.listenResume,
                      icon: AppIcon(
                        state.listening ? AppIcons.pause : AppIcons.mic,
                        size: 20,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: AppParams.spacing12.w),
                  AppPlatformOutlinedButton(
                    onPressed: onStop,
                    text: l10n.listenStop,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Explains why captions stopped, with the action that fixes it.
class _BlockBanner extends ConsumerWidget {
  const _BlockBanner({required this.block});

  final ListenBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final online = ref.watch(onlineProvider).value ?? false;
    return switch (block) {
      ListenBlock.noEngine => AppBanner(
        kind: AppBannerKind.warning,
        message: l10n.listenPausedNoEngine,
        actionLabel: online ? l10n.conversationDownloadPacks : null,
        onAction: () => context.pushNamed(AppRouteName.languagePacks),
      ),
      ListenBlock.noSpeechModel => AppBanner(
        kind: AppBannerKind.warning,
        message: l10n.listenPausedNoSpeechModel,
        actionLabel: l10n.conversationDownloadPacks,
        onAction: () => context.pushNamed(AppRouteName.languagePacks),
      ),
      ListenBlock.micDenied => AppBanner(
        kind: AppBannerKind.error,
        message: l10n.listenPausedMicDenied,
        actionLabel: l10n.conversationOpenSettings,
        onAction: () => ref.read(systemSettingsProvider).openAppSettings(),
      ),
    };
  }
}

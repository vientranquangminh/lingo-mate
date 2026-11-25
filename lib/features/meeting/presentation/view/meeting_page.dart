import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_banner.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/caption_scale.dart';
import '../../../../common/widgets/caption_settings_sheet.dart';
import '../../../../common/widgets/engine_chip.dart';
import '../../../../common/widgets/engine_sheet.dart';
import '../../../../common/widgets/explainer_sheet.dart';
import '../../../../common/widgets/mic_permission_gate.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../../../common/widgets/source_language_pill.dart';
import '../../../../core/background/background_capture.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../navigation/route_const.dart';
import '../../data/model/meeting_models.dart';
import '../../data/notifier/meeting_notifier.dart';
import '../../data/notifier/meeting_setup_notifier.dart';
import '../../data/state/meeting_state.dart';
import '../widget/meeting_line_tile.dart';

/// Meeting screen S-07: setup card, overlay permission flow, the full transcript with speaker changes, and Stop (F-04).
class MeetingPage extends ConsumerStatefulWidget {
  const MeetingPage({super.key});

  @override
  ConsumerState<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends ConsumerState<MeetingPage> {
  final _scroll = ScrollController();
  late final AppLifecycleListener _lifecycle;
  Completer<void>? _resumed;

  MeetingNotifier get _notifier => ref.read(meetingProvider.notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final resumed = _resumed;
        _resumed = null;
        if (resumed != null && !resumed.isCompleted) {
          resumed.complete();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Returns whether floating captions may be shown, explaining and opening the system setting first (AC-04.2).
  Future<bool> _overlayAllowed() async {
    final background = ref.read(backgroundCaptureProvider);
    if (await background.canDrawOverlays()) {
      return true;
    }
    if (!mounted) {
      return false;
    }
    final l10n = context.localization;
    final open = await showExplainerSheet(
      context: context,
      icon: AppIcons.modeMeeting,
      title: l10n.meetingOverlayTitle,
      body: l10n.meetingOverlayBody,
      primary: l10n.meetingOverlayOpenSettings,
      secondary: l10n.meetingOverlayInAppOnly,
    );
    if (!open) {
      return false;
    }
    final resumed = Completer<void>();
    _resumed = resumed;
    await background.openOverlaySettings();
    await resumed.future;
    return background.canDrawOverlays();
  }

  /// Asks for the microphone and the overlay, then starts the meeting.
  Future<void> _start() async {
    if (!await ensureMicAccess(context, ref)) {
      return;
    }
    final overlay = await _overlayAllowed();
    if (mounted) {
      await _notifier.start(overlay: overlay);
    }
  }

  /// Turns floating captions on (asking for permission when needed) or off.
  Future<void> _toggleOverlay(bool on) async {
    if (on && !await _overlayAllowed()) {
      return;
    }
    await _notifier.setOverlay(on);
  }

  /// Keeps the newest line in view.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppParams.standardDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(meetingProvider);
    final dismissed = ref.watch(meetingSetupDismissedProvider);
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    ref.listen(meetingProvider.select((s) => s.lines.length), (previous, next) {
      if (next > (previous ?? 0)) {
        _scrollToEnd();
      }
    });
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(state: state, onOverlay: _toggleOverlay),
            if (state.block != null)
              _Padded(child: _BlockBanner(block: state.block!)),
            if (state.running && state.inAppOnly)
              _Padded(
                child: AppBanner(
                  kind: AppBannerKind.info,
                  message: l10n.meetingInAppOnly,
                  actionLabel: l10n.meetingAllowOverlay,
                  onAction: () => _toggleOverlay(true),
                ),
              ),
            Expanded(
              child: state.lines.isEmpty
                  ? _Empty(state: state, setupDismissed: dismissed)
                  : CaptionScale(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.symmetric(
                          vertical: AppParams.spacing8.h,
                        ),
                        itemCount: state.lines.length,
                        itemBuilder: (context, index) {
                          final line = state.lines[index];
                          final translation = line.translation;
                          return MeetingLineTile(
                            key: ValueKey(line.id),
                            line: line,
                            onLongPress: translation == null
                                ? null
                                : () => saveToPhrasebook(
                                    context,
                                    ref,
                                    source: 'meeting',
                                    sourceLang: line.from,
                                    sourceText: line.original,
                                    targetLang: line.to,
                                    targetText: translation,
                                  ),
                          );
                        },
                      ),
                    ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppParams.spacing20.w,
                  vertical: AppParams.spacing12.h,
                ),
                child: state.running
                    ? AppPlatformElevatedButton(
                        onPressed: _notifier.stop,
                        text: l10n.meetingStop,
                        color: scheme.error,
                        textColor: scheme.onError,
                        icon: AppIcon(
                          AppIcons.stop,
                          size: 20,
                          color: scheme.onError,
                        ),
                      )
                    : AppPlatformElevatedButton(
                        onPressed: _start,
                        loading: state.starting,
                        text: l10n.meetingStart,
                        icon: AppIcon(
                          AppIcons.mic,
                          size: 20,
                          color: scheme.onPrimary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Side padding for banners under the header.
class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppParams.spacing20.w,
      AppParams.spacing12.h,
      AppParams.spacing20.w,
      0,
    ),
    child: child,
  );
}

/// Back, the meeting language pill, the engine chip, the floating captions switch and caption settings.
class _Header extends ConsumerWidget {
  const _Header({required this.state, required this.onOverlay});

  final MeetingState state;
  final ValueChanged<bool> onOverlay;

  /// Opens the list of meeting languages.
  Future<void> _pickSource(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final matrix = await ref.read(capabilityMatrixProvider.future);
    if (!context.mounted) {
      return;
    }
    final notifier = ref.read(meetingProvider.notifier);
    await showAppActionSheet(
      context: context,
      title: l10n.meetingPickSource,
      cancel: l10n.commonCancel,
      actions: [
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
                    source: state.source.toUpperCase(),
                    target: state.target.toUpperCase(),
                    semanticLabel: l10n.meetingSourceSemantics(
                      l10n.languageName(state.source),
                    ),
                    onTap: state.running
                        ? null
                        : () => _pickSource(context, ref),
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
            if (state.running)
              AppCircleIconButton(
                icon: AppIcons.expand,
                semanticLabel: l10n.meetingOverlayToggle,
                selected: state.overlayShown,
                onPressed: () => onOverlay(!state.overlayShown),
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

/// Before the first line: the setup card the first time (AC-04.1), else a short hint.
class _Empty extends ConsumerWidget {
  const _Empty({required this.state, required this.setupDismissed});

  final MeetingState state;
  final bool setupDismissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    if (state.running) {
      return _Hint(text: l10n.meetingWaiting);
    }
    if (setupDismissed) {
      return _Hint(text: l10n.meetingIdle);
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppParams.spacing20.r),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppParams.spacing20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppParams.buttonHeight.r,
                height: AppParams.buttonHeight.r,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
                ),
                child: Center(
                  child: AppIcon(
                    AppIcons.modeMeeting,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              SizedBox(height: AppParams.spacing16.h),
              Text(
                l10n.meetingSetupTitle,
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: AppParams.spacing8.h),
              Text(
                l10n.meetingSetupBody,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppParams.spacing16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(AppIcons.privacy, size: 20, color: scheme.primary),
                  SizedBox(width: AppParams.spacing8.w),
                  Expanded(
                    child: Text(
                      l10n.meetingConsent,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppParams.spacing8.h),
              Align(
                alignment: Alignment.centerRight,
                child: AppPlatformTextButton(
                  onPressed: () => ref
                      .read(meetingSetupDismissedProvider.notifier)
                      .dismiss(),
                  text: l10n.meetingDontShowAgain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred hint line.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppParams.spacing32.w),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Explains why captions stopped, with the action that fixes it.
class _BlockBanner extends ConsumerWidget {
  const _BlockBanner({required this.block});

  final MeetingBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final online = ref.watch(onlineProvider).value ?? false;
    return switch (block) {
      MeetingBlock.noEngine => AppBanner(
        kind: AppBannerKind.warning,
        message: l10n.listenPausedNoEngine,
        actionLabel: online ? l10n.conversationDownloadPacks : null,
        onAction: () => context.pushNamed(AppRouteName.languagePacks),
      ),
      MeetingBlock.noSpeechModel => AppBanner(
        kind: AppBannerKind.warning,
        message: l10n.listenPausedNoSpeechModel,
        actionLabel: l10n.conversationDownloadPacks,
        onAction: () => context.pushNamed(AppRouteName.languagePacks),
      ),
      MeetingBlock.micDenied => AppBanner(
        kind: AppBannerKind.error,
        message: l10n.listenPausedMicDenied,
        actionLabel: l10n.conversationOpenSettings,
        onAction: () => ref.read(systemSettingsProvider).openAppSettings(),
      ),
    };
  }
}

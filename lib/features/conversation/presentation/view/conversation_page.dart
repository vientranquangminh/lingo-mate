import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/widgets/suggested_replies_sheet.dart';
import '../../../../common/widgets/keep_screen_on.dart';
import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_banner.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../common/widgets/engine_chip.dart';
import '../../../../common/widgets/engine_sheet.dart';
import '../../../../common/widgets/mic_button.dart';
import '../../../../common/widgets/mic_permission_gate.dart';
import '../../../../common/widgets/require_sign_in.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../../../core/config/feature_switches.dart';
import '../../../../core/learning/learning_models.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/live/live_access.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../generated/l10n.dart';
import '../../../../l10n/partner_strings.dart';
import '../../../../navigation/route_const.dart';
import '../../data/model/conversation_models.dart';
import '../../data/notifier/conversation_notifier.dart';
import '../../data/state/conversation_state.dart';
import '../widget/conversation_half.dart';

/// Conversation screen S-05: the partner's half on top, turned 180°, the user's half below (F-02).
class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key, required this.pair});

  final LanguagePair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = conversationProvider(pair);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    ref.listen(provider.select((s) => s.liveStops), (_, _) {
      final denial = ref.read(provider).liveDenial;
      showAppToast(
        context,
        denial == LiveDenial.quota
            ? l10n.liveQuotaFallback
            : l10n.liveUnavailableFallback,
      );
    });
    ref.listen(provider.select((s) => s.switchCount), (_, _) {
      final engine = ref.read(provider).switchedTo;
      if (engine != null) {
        showAppToast(
          context,
          l10n.conversationSwitchedTo(_engineName(l10n, engine)),
        );
      }
    });
    final partner = PartnerStrings.forLanguage(pair.b);
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: KeepScreenOn(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: ConversationHalf(
                    strings: partner,
                    incoming: state.lastBy(Speaker.a),
                    micState: _micState(state, Speaker.b),
                    onMic: () => _toggleMic(context, ref, Speaker.b),
                    background: scheme.inverseSurface,
                    foreground: scheme.onInverseSurface,
                    mutedForeground: scheme.onInverseSurface.withValues(
                      alpha: 0.72,
                    ),
                    micBackground: scheme.surface,
                    micForeground: scheme.onSurface,
                    onLongPressIncoming: (turn) =>
                        _showActions(context, ref, turn),
                  ),
                ),
              ),
              _Divider(state: state, pair: pair),
              Expanded(
                child: ConversationHalf(
                  strings: PartnerStrings.fromLocalizations(l10n, pair.a),
                  incoming: state.lastBy(Speaker.b),
                  micState: _micState(state, Speaker.a),
                  onMic: () => _toggleMic(context, ref, Speaker.a),
                  background: scheme.surface,
                  foreground: scheme.onSurface,
                  mutedForeground: scheme.onSurfaceVariant,
                  micBackground: scheme.primary,
                  micForeground: scheme.onPrimary,
                  onLongPressIncoming: (turn) =>
                      _showActions(context, ref, turn),
                  leading:
                      !ref.watch(
                        featureSwitchesProvider.select((s) => s.suggestReply),
                      )
                      ? null
                      : AppCircleIconButton(
                          icon: AppIcons.suggestReply,
                          semanticLabel: l10n.learningSuggestReply,
                          onPressed:
                              state.turns.any((t) => t.translation != null) &&
                                  (ref.watch(onlineProvider).value ?? true)
                              ? () => _suggest(context, ref)
                              : null,
                        ),
                  banner: state.paused != null
                      ? _PausedBanner(reason: state.paused!)
                      : state.liveListening
                      ? AppBanner(
                          kind: AppBannerKind.info,
                          message: l10n.conversationLiveOn,
                        )
                      : state.auto
                      ? AppBanner(
                          kind: AppBannerKind.info,
                          message: l10n.conversationAutoOn,
                        )
                      : null,
                  trailing: AppCircleIconButton(
                    icon: state.speakOn
                        ? AppIcons.speaker
                        : AppIcons.speakerOff,
                    semanticLabel: state.speakOn
                        ? l10n.conversationSpeakOn
                        : l10n.conversationSpeakOff,
                    selected: state.speakOn,
                    onPressed: () => notifier.setSpeakOn(!state.speakOn),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Suggests three replies in the partner's language; a tapped one is spoken (AC-19.1, AC-19.2).
  Future<void> _suggest(BuildContext context, WidgetRef ref) =>
      showSuggestedRepliesSheet(
        context,
        recent: [
          for (final turn in ref.read(conversationProvider(pair)).turns)
            if (turn.translation != null)
              LearningLine(
                speaker: turn.speaker.name,
                sourceLang: turn.from,
                sourceText: turn.original,
                targetLang: turn.to,
                targetText: turn.translation!,
              ),
        ],
        replyLang: pair.b,
        userLang: pair.a,
        pickHint: context.localization.learningTapToSpeak,
        onPick: (reply) => ref
            .read(conversationProvider(pair).notifier)
            .speakText(reply.text, pair.b),
      );

  /// Toggles [speaker]'s mic, explaining and asking for the microphone first when needed (AC-01.6).
  Future<void> _toggleMic(
    BuildContext context,
    WidgetRef ref,
    Speaker speaker,
  ) async {
    final notifier = ref.read(conversationProvider(pair).notifier);
    if (ref.read(conversationProvider(pair)).listening == speaker ||
        await ensureMicAccess(context, ref) &&
            context.mounted &&
            await prepareLive(context, ref, pair)) {
      await notifier.toggleMic(speaker);
    }
  }

  /// Before starting on Live, asks to sign in; declining switches to the text engines (AC-13.6). Always returns true.
  static Future<bool> prepareLive(
    BuildContext context,
    WidgetRef ref,
    LanguagePair pair,
  ) async {
    final state = ref.read(conversationProvider(pair));
    if (state.engine == EngineKind.live &&
        !state.liveListening &&
        !await requireSignIn(context, ref, SignInReason.live)) {
      ref.read(conversationProvider(pair).notifier).skipLive();
    }
    return true;
  }

  /// Offers Replay, Copy and Show large for a line (AC-02.6).
  void _showActions(
    BuildContext context,
    WidgetRef ref,
    ConversationTurn turn,
  ) {
    final l10n = context.localization;
    final translation = turn.translation;
    final shown = translation ?? turn.original;
    showAppActionSheet(
      context: context,
      title: l10n.bubbleActions,
      cancel: l10n.commonCancel,
      actions: [
        if (translation != null)
          AppSheetAction(
            icon: AppIcons.replay,
            label: l10n.bubbleReplay,
            onSelected: () =>
                ref.read(conversationProvider(pair).notifier).replay(turn),
          ),
        if (translation != null)
          AppSheetAction(
            icon: AppIcons.bookmark,
            label: l10n.phraseSave,
            onSelected: () async {
              final utteranceId = await ref
                  .read(conversationProvider(pair).notifier)
                  .utteranceIdFor(turn.id);
              if (context.mounted) {
                await saveToPhrasebook(
                  context,
                  ref,
                  source: 'conversation',
                  sourceLang: turn.from,
                  sourceText: turn.original,
                  targetLang: turn.to,
                  targetText: translation,
                  fromUtteranceId: utteranceId,
                );
              }
            },
          ),
        AppSheetAction(
          icon: AppIcons.copy,
          label: l10n.bubbleCopy,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: shown));
            if (context.mounted) {
              showAppToast(context, l10n.bubbleCopied);
            }
          },
        ),
        AppSheetAction(
          icon: AppIcons.modeShow,
          label: l10n.bubbleShowLarge,
          onSelected: () => context.pushNamed(
            AppRouteName.showMode,
            extra: <String, String?>{
              'text': shown,
              'original': translation == null ? null : turn.original,
              'lang': translation == null ? turn.from : turn.to,
            },
          ),
        ),
      ],
    );
  }

  /// Returns what [speaker]'s mic shows.
  static MicButtonState _micState(ConversationState state, Speaker speaker) {
    if (state.listening == speaker) {
      return MicButtonState.listening;
    }
    if (state.auto && !state.processing && !state.speaking) {
      return MicButtonState.listening;
    }
    if (state.processing) {
      return MicButtonState.processing;
    }
    if (state.speaking) {
      return MicButtonState.speaking;
    }
    return MicButtonState.idle;
  }

  /// Returns the display name of [engine].
  static String _engineName(AppLocalizations l10n, EngineKind engine) =>
      switch (engine) {
        EngineKind.offline => l10n.engineOffline,
        EngineKind.standard => l10n.engineStandard,
        EngineKind.live => l10n.engineLive,
      };
}

/// The bar between the halves: back and the engine chip.
class _Divider extends ConsumerWidget {
  const _Divider({required this.state, required this.pair});

  final ConversationState state;
  final LanguagePair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              semanticLabel: context.localization.conversationBack,
              borderColor: Colors.transparent,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Center(
                child: EngineChip(
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
              ),
            ),
            Flexible(
              child: AppPlatformOutlinedButton(
                onPressed: () async {
                  final notifier = ref.read(
                    conversationProvider(pair).notifier,
                  );
                  if (state.auto ||
                      await ensureMicAccess(context, ref) &&
                          context.mounted &&
                          await ConversationPage.prepareLive(
                            context,
                            ref,
                            pair,
                          )) {
                    await notifier.toggleAuto();
                  }
                },
                text: context.localization.conversationAutoDetect,
                backgroundColor: state.auto ? scheme.primaryContainer : null,
                foregroundColor: state.auto
                    ? scheme.onPrimaryContainer
                    : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains why translation stopped, with the action that fixes it (AC-02.8).
class _PausedBanner extends ConsumerWidget {
  const _PausedBanner({required this.reason});

  final PauseReason reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final online = ref.watch(onlineProvider).value ?? false;
    return switch (reason) {
      PauseReason.noEngine => AppBanner(
        kind: AppBannerKind.warning,
        message: l10n.conversationPausedNoEngine,
        actionLabel: online ? l10n.conversationDownloadPacks : null,
        onAction: () => context.pushNamed(AppRouteName.languagePacks),
      ),
      PauseReason.noSpeechModel => AppBanner(
        kind: AppBannerKind.warning,
        message: l10n.conversationPausedNoSpeechModel,
        actionLabel: l10n.conversationDownloadPacks,
        onAction: () => context.pushNamed(AppRouteName.languagePacks),
      ),
      PauseReason.micDenied => AppBanner(
        kind: AppBannerKind.error,
        message: l10n.conversationPausedMicDenied,
        actionLabel: l10n.conversationOpenSettings,
        onAction: () => ref.read(systemSettingsProvider).openAppSettings(),
      ),
    };
  }
}

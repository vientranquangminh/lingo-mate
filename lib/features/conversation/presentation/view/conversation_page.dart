import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_banner.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../common/widgets/engine_chip.dart';
import '../../../../common/widgets/engine_sheet.dart';
import '../../../../common/widgets/mic_button.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../generated/l10n.dart';
import '../../../../navigation/route_const.dart';
import '../../data/model/conversation_models.dart';
import '../../data/notifier/conversation_notifier.dart';
import '../../data/state/conversation_state.dart';
import '../widget/conversation_half.dart';

/// Conversation screen S-05: the partner's half on top, turned 180°, the user's half below (F-02).
class ConversationPage extends ConsumerWidget {
  const ConversationPage({super.key, required this.pair});

  final LanguagePair pair;

  /// Returns the partner-facing strings in [lang], English when the app has none (F-11).
  static AppLocalizations partnerStrings(String lang) {
    final locale = Locale(lang);
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == lang,
    );
    return lookupAppLocalizations(supported ? locale : const Locale('en'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = conversationProvider(pair);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    ref.listen(provider.select((s) => s.switchCount), (_, _) {
      final engine = ref.read(provider).switchedTo;
      if (engine != null) {
        showAppToast(
          context,
          l10n.conversationSwitchedTo(_engineName(l10n, engine)),
        );
      }
    });
    final partner = partnerStrings(pair.b);
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: 2,
                child: ConversationHalf(
                  strings: partner,
                  languageName: partner.languageName(pair.b),
                  incoming: state.lastBy(Speaker.a),
                  micState: _micState(state, Speaker.b),
                  onMic: () => notifier.toggleMic(Speaker.b),
                  background: scheme.inverseSurface,
                  foreground: scheme.onInverseSurface,
                  mutedForeground: scheme.onInverseSurface.withValues(
                    alpha: 0.72,
                  ),
                  micBackground: scheme.surface,
                  micForeground: scheme.onSurface,
                ),
              ),
            ),
            _Divider(state: state, pair: pair),
            Expanded(
              child: ConversationHalf(
                strings: l10n,
                languageName: l10n.languageName(pair.a),
                incoming: state.lastBy(Speaker.b),
                micState: _micState(state, Speaker.a),
                onMic: () => notifier.toggleMic(Speaker.a),
                background: scheme.surface,
                foreground: scheme.onSurface,
                mutedForeground: scheme.onSurfaceVariant,
                micBackground: scheme.primary,
                micForeground: scheme.onPrimary,
                banner: state.paused == null
                    ? null
                    : _PausedBanner(reason: state.paused!),
                trailing: AppCircleIconButton(
                  icon: state.speakOn ? AppIcons.speaker : AppIcons.speakerOff,
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
    );
  }

  /// Returns what [speaker]'s mic shows.
  static MicButtonState _micState(ConversationState state, Speaker speaker) {
    if (state.listening == speaker) {
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
            SizedBox(width: AppParams.buttonHeight.r),
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

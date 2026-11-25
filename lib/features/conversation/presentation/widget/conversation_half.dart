import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/widgets/caption_scale.dart';
import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/mic_button.dart';
import '../../../../l10n/partner_strings.dart';
import '../../data/model/conversation_models.dart';

/// One person's half: their language, the latest line said to them and their mic (S-05).
class ConversationHalf extends StatelessWidget {
  const ConversationHalf({
    super.key,
    required this.strings,
    required this.incoming,
    required this.micState,
    required this.onMic,
    required this.background,
    required this.foreground,
    required this.mutedForeground,
    required this.micBackground,
    required this.micForeground,
    this.leading,
    this.trailing,
    this.banner,
    this.onLongPressIncoming,
    this.draft,
  });

  final PartnerStrings strings;
  final ConversationTurn? incoming;
  final MicButtonState micState;
  final VoidCallback onMic;
  final Color background;
  final Color foreground;
  final Color mutedForeground;
  final Color micBackground;
  final Color micForeground;
  final Widget? leading;
  final Widget? trailing;
  final Widget? banner;
  final ValueChanged<ConversationTurn>? onLongPressIncoming;
  final String? draft;

  @override
  Widget build(BuildContext context) {
    final label = switch (micState) {
      MicButtonState.listening => strings.listening,
      MicButtonState.processing => strings.translating,
      MicButtonState.speaking => strings.speaking,
      _ => strings.tapToSpeak,
    };
    return ColoredBox(
      color: background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppParams.spacing20.w,
          AppParams.spacing16.h,
          AppParams.spacing20.w,
          AppParams.spacing8.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.languageName.toUpperCase(),
              style: context.textTheme.labelLarge?.copyWith(
                color: mutedForeground,
              ),
            ),
            SizedBox(height: AppParams.spacing8.h),
            Expanded(
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?banner,
                    if (banner != null) SizedBox(height: AppParams.spacing12.h),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress:
                          incoming == null || onLongPressIncoming == null
                          ? null
                          : () => onLongPressIncoming!(incoming!),
                      child: CaptionScale(
                        child: draft != null
                            ? Text(
                                draft!,
                                style: context.textTheme.bodyLarge?.copyWith(
                                  color: mutedForeground,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : _Incoming(
                                turn: incoming,
                                strings: strings,
                                foreground: foreground,
                                mutedForeground: mutedForeground,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: leading),
                ),
                MicButton(
                  state: micState,
                  label: label,
                  semanticLabel: strings.micSemantics(strings.languageName),
                  onPressed: onMic,
                  size: AppParams.micConversation,
                  background: micBackground,
                  foreground: micForeground,
                  labelColor: foreground,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The original (small) and translation (large) of the latest line said to this person.
class _Incoming extends StatelessWidget {
  const _Incoming({
    required this.turn,
    required this.strings,
    required this.foreground,
    required this.mutedForeground,
  });

  final ConversationTurn? turn;
  final PartnerStrings strings;
  final Color foreground;
  final Color mutedForeground;

  @override
  Widget build(BuildContext context) {
    final turn = this.turn;
    if (turn == null) {
      return const SizedBox.shrink();
    }
    final translation = switch (turn.status) {
      TurnStatus.translated => turn.translation,
      TurnStatus.failed => strings.translationFailed,
      _ => null,
    };
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            turn.original,
            style: context.textTheme.bodyLarge?.copyWith(
              color: mutedForeground,
            ),
          ),
          if (translation != null) ...[
            SizedBox(height: AppParams.spacing8.h),
            Text(
              translation,
              style: context.textTheme.headlineMedium?.copyWith(
                color: foreground,
              ),
            ),
          ],
          if (turn.fallback) ...[
            SizedBox(height: AppParams.spacing4.h),
            Text(
              strings.translatedOffline,
              style: context.textTheme.labelMedium?.copyWith(
                color: mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

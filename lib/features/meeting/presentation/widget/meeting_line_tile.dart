import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_colors.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_motion.dart';
import '../../data/model/meeting_models.dart';

/// One transcript line in its speaker's colour, naming the speaker when they change; without speaker labels, a "New speaker" divider after a long pause (S-07).
class MeetingLineTile extends StatelessWidget {
  const MeetingLineTile({
    super.key,
    required this.line,
    this.onLongPress,
    this.showSpeaker = true,
  });

  final MeetingLine line;
  final VoidCallback? onLongPress;
  final bool showSpeaker;

  /// Returns [ms] as m:ss.
  static String time(int ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final translation = switch (line.status) {
      MeetingLineStatus.translated => line.translation,
      MeetingLineStatus.failed => l10n.conversationTranslationFailed,
      MeetingLineStatus.translating => l10n.conversationTranslating,
      MeetingLineStatus.paused => null,
    };
    final muted = line.status != MeetingLineStatus.translated;
    final speaker = line.speaker;
    final speakerColor = speaker == null
        ? null
        : context.appColors.speaker(speaker);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (line.newTurn && line.speaker == null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppParams.spacing20.w,
              AppParams.spacing12.h,
              AppParams.spacing20.w,
              0,
            ),
            child: Row(
              children: [
                Expanded(child: Divider(color: scheme.outlineVariant)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppParams.spacing8.w,
                  ),
                  child: Text(
                    l10n.meetingNewSpeaker,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: scheme.outlineVariant)),
              ],
            ),
          ),
        InkWell(
          onLongPress: onLongPress,
          child: Semantics(
            liveRegion: true,
            label: speaker == null ? null : l10n.meetingSpeaker(speaker),
            child: Container(
              decoration: speakerColor == null
                  ? null
                  : BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(
                          color: speakerColor,
                          width: AppParams.speakerBarWidth.w,
                        ),
                      ),
                    ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppParams.spacing20.w,
                  vertical: AppParams.spacing12.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (speaker != null &&
                            speakerColor != null &&
                            showSpeaker) ...[
                          Text(
                            l10n.meetingSpeaker(speaker),
                            style: context.textTheme.labelMedium?.copyWith(
                              color: speakerColor,
                            ),
                          ),
                          Text(
                            ' · ',
                            style: context.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        Text(
                          time(line.atMs),
                          style: context.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    AppSwitcher(
                      child: translation == null
                          ? const SizedBox(key: ValueKey('none'))
                          : Padding(
                              key: ValueKey(line.status),
                              padding: EdgeInsets.only(
                                top: AppParams.spacing4.h,
                              ),
                              child: Text(
                                translation,
                                style: context.textTheme.titleLarge?.copyWith(
                                  color: muted
                                      ? scheme.onSurfaceVariant
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                    ),
                    SizedBox(height: AppParams.spacing4.h),
                    Text(
                      line.original,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (line.fallback) ...[
                      SizedBox(height: AppParams.spacing4.h),
                      Text(
                        l10n.conversationTranslatedOffline,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

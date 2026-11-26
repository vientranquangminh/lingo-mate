import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_motion.dart';
import '../../data/model/meeting_models.dart';

/// One transcript line, with a "New speaker" divider above it after a long pause (S-07).
class MeetingLineTile extends StatelessWidget {
  const MeetingLineTile({super.key, required this.line, this.onLongPress});

  final MeetingLine line;
  final VoidCallback? onLongPress;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (line.newTurn)
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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppParams.spacing20.w,
                vertical: AppParams.spacing12.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time(line.atMs),
                    style: context.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  AppSwitcher(
                    child: translation == null
                        ? const SizedBox(key: ValueKey('none'))
                        : Padding(
                            key: ValueKey(line.status),
                            padding: EdgeInsets.only(top: AppParams.spacing4.h),
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
      ],
    );
  }
}

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_motion.dart';
import '../../data/model/listen_models.dart';

/// One caption: time from the start, the translation large and the original small below (S-06).
class CaptionTile extends StatelessWidget {
  const CaptionTile({super.key, required this.caption});

  final Caption caption;

  /// Returns [ms] as m:ss.
  static String time(int ms) {
    final seconds = ms ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final translation = switch (caption.status) {
      CaptionStatus.translated => caption.translation,
      CaptionStatus.failed => l10n.conversationTranslationFailed,
      CaptionStatus.translating => l10n.conversationTranslating,
      CaptionStatus.paused => null,
    };
    final muted = caption.status != CaptionStatus.translated;
    return Semantics(
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
              time(caption.atMs),
              style: context.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            AppSwitcher(
              child: translation == null
                  ? const SizedBox(key: ValueKey('none'))
                  : Padding(
                      key: ValueKey(caption.status),
                      padding: EdgeInsets.only(top: AppParams.spacing4.h),
                      child: Text(
                        translation,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: muted
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
            ),
            SizedBox(height: AppParams.spacing4.h),
            Text(
              caption.original,
              style: context.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (caption.fallback) ...[
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
    );
  }
}

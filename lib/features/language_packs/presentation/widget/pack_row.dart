import '../../../../common/widgets/app_motion.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_colors.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../data/model/pack_models.dart';

/// One language's offline pack: name, sizes, status and its action (doc 08 PackRow).
class PackRow extends StatelessWidget {
  const PackRow({
    super.key,
    required this.pack,
    required this.name,
    required this.endonym,
    required this.isPivot,
    required this.onDownload,
    required this.onDelete,
    required this.onInstallVoice,
  });

  final LanguagePack pack;
  final String name;
  final String endonym;
  final bool isPivot;
  final VoidCallback onDownload;
  final VoidCallback? onDelete;
  final VoidCallback onInstallVoice;

  /// Formats bytes as whole megabytes.
  static String megabytes(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final status = pack.status;
    final title = name == endonym ? name : '$name · $endonym';
    final subtitle = switch (status) {
      PackStatus.notAvailableOffline => l10n.packsNotOffline,
      PackStatus.downloading => l10n.packsDownloading(
        (pack.speechProgress * 100).round(),
      ),
      PackStatus.waitingForWifi => l10n.packsWaitingWifi,
      _ when isPivot => l10n.packsPivotNote,
      _ when pack.speechSpec == null => l10n.packsSpeechNotConfigured,
      _ => l10n.packsSizes(
        megabytes(pack.speechBytes),
        megabytes(LanguagePack.translationBytes),
      ),
    };
    final unavailable = status == PackStatus.notAvailableOffline;
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: AppParams.spacing12.h),
      color: unavailable
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        side: unavailable
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        onLongPress: onDelete,
        child: Padding(
          padding: EdgeInsets.all(AppParams.spacing16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        SizedBox(height: AppParams.spacing4.h),
                        Text(
                          subtitle,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppParams.spacing8.w),
                  _Action(status: status, onDownload: onDownload),
                ],
              ),
              if (status == PackStatus.downloading) ...[
                SizedBox(height: AppParams.spacing12.h),
                if (pack.speechSpec == null)
                  LinearProgressIndicator(
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHigh,
                  )
                else
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: pack.speechProgress),
                    duration: AppMotion.of(context),
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ),
              ],
              if (status == PackStatus.ready && pack.voiceMissing)
                Padding(
                  padding: EdgeInsets.only(top: AppParams.spacing8.h),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.warning,
                        size: AppParams.engineIcon,
                        color: context.appColors.warning,
                      ),
                      SizedBox(width: AppParams.spacing4.w),
                      Expanded(
                        child: Text(
                          l10n.packsVoiceMissing,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      AppPlatformTextButton(
                        onPressed: onInstallVoice,
                        text: l10n.packsInstallVoice,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trailing status or action of a pack row.
class _Action extends StatelessWidget {
  const _Action({required this.status, required this.onDownload});

  final PackStatus status;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final success = context.appColors.success;
    return switch (status) {
      PackStatus.ready => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.check, size: AppParams.engineIcon, color: success),
          SizedBox(width: AppParams.spacing4.w),
          Text(
            l10n.packsReady,
            style: context.textTheme.labelLarge?.copyWith(color: success),
          ),
        ],
      ),
      PackStatus.notDownloaded => AppPlatformOutlinedButton(
        onPressed: onDownload,
        text: l10n.packsDownload,
      ),
      PackStatus.failed => AppPlatformOutlinedButton(
        onPressed: onDownload,
        text: l10n.packsRetry,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

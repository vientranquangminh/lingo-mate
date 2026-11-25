import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../../../common/widgets/speak_or_show.dart';
import '../../../../core/learning/learning_models.dart';

/// One roleplay message: the partner's line with its translation and a speaker, or the learner's line with feedback.
class RoleplayBubble extends ConsumerWidget {
  const RoleplayBubble({
    super.key,
    required this.message,
    required this.targetLang,
    required this.userLang,
  });

  final RoleplayMessage message;
  final String targetLang;
  final String userLang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final mine = message.fromLearner;
    final translation = message.translation;
    final feedback = message.feedback;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: Padding(
          padding: EdgeInsets.only(bottom: AppParams.spacing12.h),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(AppParams.spacing12.r),
                decoration: BoxDecoration(
                  color: mine
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.text,
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: mine
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                          if (translation != null && translation.isNotEmpty)
                            Text(
                              translation,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!mine)
                      AppCircleIconButton(
                        icon: AppIcons.speaker,
                        semanticLabel: l10n.roleplayListen,
                        borderColor: Colors.transparent,
                        size: 40,
                        onPressed: () => speakOrShow(
                          context,
                          ref,
                          text: message.text,
                          lang: targetLang,
                          original: translation,
                        ),
                      ),
                  ],
                ),
              ),
              if (feedback != null) ...[
                SizedBox(height: AppParams.spacing4.h),
                Container(
                  padding: EdgeInsets.all(AppParams.spacing12.r),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.learningNativeWouldSay,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      Text(
                        feedback.improved,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      if (feedback.reason.isNotEmpty)
                        Text(
                          feedback.reason,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      if (feedback.meaning.isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: AppCircleIconButton(
                            icon: AppIcons.bookmark,
                            semanticLabel: l10n.phraseSave,
                            borderColor: Colors.transparent,
                            size: 40,
                            onPressed: () => saveToPhrasebook(
                              context,
                              ref,
                              source: 'roleplay',
                              sourceLang: userLang,
                              sourceText: feedback.meaning,
                              targetLang: targetLang,
                              targetText: feedback.improved,
                              note: feedback.reason,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

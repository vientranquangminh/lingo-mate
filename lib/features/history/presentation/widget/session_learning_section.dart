import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../core/config/feature_switches.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/learning/learning_assistant.dart';
import '../../../../core/learning/learning_models.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../../../core/settings/user_settings.dart';
import '../../../../navigation/route_const.dart';
import '../../data/notifier/history_providers.dart';

/// The transcript's summary card or Summarize button (F-20) and the post-session review button (F-17).
class SessionLearningSection extends ConsumerStatefulWidget {
  const SessionLearningSection({
    super.key,
    required this.detail,
    required this.title,
  });

  final SessionDetail detail;
  final String title;

  @override
  ConsumerState<SessionLearningSection> createState() =>
      _SessionLearningSectionState();
}

class _SessionLearningSectionState
    extends ConsumerState<SessionLearningSection> {
  bool _summarizing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final session = widget.detail.session;
    final online = ref.watch(onlineProvider).value ?? true;
    final recap = SessionRecap.decode(session.summary);
    final canSummarize =
        LearningRules.canSummarize(session.mode, session.durationSec) &&
        ref.watch(featureSwitchesProvider.select((s) => s.summary));
    final canReview =
        LearningRules.canReview(widget.detail.utterances) &&
        ref.watch(featureSwitchesProvider.select((s) => s.postSessionReview));
    if (recap == null && !canSummarize && !canReview) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recap != null)
          _SummaryCard(recap: recap, title: widget.title)
        else if (canSummarize)
          _ActionButton(
            icon: AppIcons.summarize,
            label: l10n.learningSummarize,
            online: online,
            busy: _summarizing,
            onPressed: _summarize,
          ),
        if (canReview) ...[
          SizedBox(height: AppParams.spacing8.h),
          _ActionButton(
            icon: AppIcons.edit,
            label: l10n.learningReviewButton,
            online: online,
            onPressed: () => context.pushNamed(
              AppRouteName.phrasingReview,
              pathParameters: {'id': session.id},
            ),
          ),
        ],
        SizedBox(height: AppParams.spacing16.h),
      ],
    );
  }

  /// Asks for the summary in the user's language and stores it with the session (AC-20.1).
  Future<void> _summarize() async {
    final l10n = context.localization;
    final detail = widget.detail;
    final userLang =
        ref.read(userSettingsProvider).myLanguage ?? detail.session.langB;
    setState(() => _summarizing = true);
    try {
      final recap = await ref
          .read(learningAssistantProvider)
          .summarize(
            lines: [
              for (final u in detail.utterances) LearningLine.fromUtterance(u),
            ],
            userLang: userLang,
          );
      await ref
          .read(sessionRepositoryProvider)
          .saveSummary(detail.session.id, recap.encode());
      ref.invalidate(transcriptProvider(detail.session.id));
    } on Object {
      if (mounted) {
        showAppToast(context, l10n.learningFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _summarizing = false);
      }
    }
  }
}

/// An outlined action that is disabled offline with "Needs internet" (AC-17.3).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.online,
    required this.onPressed,
    this.busy = false,
  });

  final AppIcons icon;
  final String label;
  final bool online;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPlatformOutlinedButton(
          onPressed: online && !busy ? onPressed : null,
          text: busy ? l10n.learningWorking : label,
        ),
        if (!online)
          Padding(
            padding: EdgeInsets.only(top: AppParams.spacing4.h),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.wifiOff,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(width: AppParams.spacing4.w),
                Text(
                  l10n.learningNeedsInternet,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The stored summary with key terms, action items and Share (AC-20.1, AC-20.2).
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.recap, required this.title});

  final SessionRecap recap;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    Widget heading(String text) => Padding(
      padding: EdgeInsets.only(
        top: AppParams.spacing12.h,
        bottom: AppParams.spacing4.h,
      ),
      child: Text(
        text,
        style: context.textTheme.labelLarge?.copyWith(color: scheme.onSurface),
      ),
    );
    Widget bullet(String text) => Padding(
      padding: EdgeInsets.only(bottom: AppParams.spacing4.h),
      child: Text(
        '• $text',
        style: context.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
    );
    return Container(
      padding: EdgeInsets.all(AppParams.spacing16.r),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(AppIcons.summarize, color: scheme.onPrimaryContainer),
              SizedBox(width: AppParams.spacing8.w),
              Expanded(
                child: Text(
                  l10n.learningSummaryTitle,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              AppCircleIconButton(
                icon: AppIcons.share,
                semanticLabel: l10n.learningShareSummary,
                borderColor: Colors.transparent,
                color: scheme.onPrimaryContainer,
                onPressed: () => ref
                    .read(systemSettingsProvider)
                    .shareText(
                      LearningRules.summaryText(
                        recap,
                        title: title,
                        keyTermsLabel: l10n.learningKeyTerms,
                        actionItemsLabel: l10n.learningActionItems,
                      ),
                      subject: title,
                    ),
              ),
            ],
          ),
          Text(
            recap.summary,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          if (recap.keyTerms.isNotEmpty) ...[
            heading(l10n.learningKeyTerms),
            for (final term in recap.keyTerms) bullet(term),
          ],
          if (recap.actionItems.isNotEmpty) ...[
            heading(l10n.learningActionItems),
            for (final item in recap.actionItems) bullet(item),
          ],
        ],
      ),
    );
  }
}

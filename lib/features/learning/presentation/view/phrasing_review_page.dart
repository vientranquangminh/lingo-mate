import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_circular_progress_indicator.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../data/notifier/phrasing_review_providers.dart';

/// S-21 Post-session review: "You said" → "A native speaker would say", a reason and Save (F-17).
class PhrasingReviewPage extends ConsumerWidget {
  const PhrasingReviewPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final review = ref.watch(phrasingReviewProvider(sessionId));
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
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
                  SizedBox(width: AppParams.spacing8.w),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.learningReviewTitle,
                        style: context.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: review.when(
                loading: () => Center(
                  child: AppCircularProgressIndicator(color: scheme.primary),
                ),
                error: (_, _) => _Message(
                  text: l10n.learningFailed,
                  action: l10n.learningRetry,
                  onAction: () =>
                      ref.invalidate(phrasingReviewProvider(sessionId)),
                ),
                data: (items) => items.isEmpty
                    ? _Message(text: l10n.learningReviewNothing)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          AppParams.spacing20.w,
                          AppParams.spacing8.h,
                          AppParams.spacing20.w,
                          AppParams.spacing24.h,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: AppParams.spacing12.h),
                        itemBuilder: (context, i) => _TipCard(item: items[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tip with its Save button (AC-17.2).
class _TipCard extends ConsumerWidget {
  const _TipCard({required this.item});

  final PhrasingReviewItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final tip = item.tip;
    return Container(
      padding: EdgeInsets.all(AppParams.spacing16.r),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.learningYouSaid,
            style: context.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: AppParams.spacing4.h),
          Text(
            tip.original,
            style: context.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: AppParams.spacing12.h),
          Text(
            l10n.learningNativeWouldSay,
            style: context.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
            ),
          ),
          SizedBox(height: AppParams.spacing4.h),
          Text(
            tip.improved,
            style: context.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          if (tip.reason.isNotEmpty) ...[
            SizedBox(height: AppParams.spacing8.h),
            Text(
              tip.reason,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: AppParams.spacing8.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppPlatformOutlinedButton(
              onPressed: () => saveToPhrasebook(
                context,
                ref,
                source: 'post_session_review',
                sourceLang: item.userLang,
                sourceText: tip.original,
                targetLang: item.partnerLang,
                targetText: tip.improved,
                note: tip.reason,
              ),
              text: l10n.commonSave,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered note with an optional action.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppParams.spacing24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              SizedBox(height: AppParams.spacing16.h),
              AppPlatformOutlinedButton(onPressed: onAction, text: action),
            ],
          ],
        ),
      ),
    );
  }
}

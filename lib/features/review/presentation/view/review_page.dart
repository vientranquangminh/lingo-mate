import '../../../../common/widgets/app_skeleton.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../core/review/review_repository.dart';
import '../../../../core/review/review_settings.dart';
import '../../../../core/review/sm2.dart';
import '../../data/notifier/review_notifier.dart';
import '../../data/state/review_state.dart';
import '../widget/reminder_settings.dart';

/// S-20 Review: due cards one by one, tap to reveal, Again/Hard/Good/Easy, progress and streak (F-16).
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(reviewProvider);
    final streak = ref.watch(
      reviewSettingsProvider.select((s) => s.streakOn(DateTime.now())),
    );
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
                        l10n.reviewTitle,
                        style: context.textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  if (streak > 0) _StreakChip(days: streak),
                  AppCircleIconButton(
                    icon: AppIcons.settings,
                    semanticLabel: l10n.reviewReminderSettings,
                    borderColor: Colors.transparent,
                    onPressed: () => showReminderSettingsSheet(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (state.status) {
                ReviewStatus.loading => const AppSkeletonList(rows: 2),
                ReviewStatus.active => _Session(state: state),
                ReviewStatus.done => _Done(state: state),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill with the streak.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: AppParams.pillPadding,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.streak, size: 16, color: scheme.onPrimaryContainer),
          SizedBox(width: AppParams.spacing4.w),
          Text(
            context.localization.reviewStreak(days),
            style: context.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// The current card, progress and the grade buttons.
class _Session extends ConsumerWidget {
  const _Session({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final card = state.current!;
    final notifier = ref.read(reviewProvider.notifier);
    final progress = state.total == 0 ? 0.0 : state.finished / state.total;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppParams.spacing20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l10n.reviewProgress(state.finished, state.total),
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
                    child: Container(
                      height: AppParams.progressBarHeight.h,
                      color: scheme.surfaceContainerHigh,
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        heightFactor: 1,
                        child: ColoredBox(color: scheme.primary),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppParams.spacing12.w),
                Text(
                  l10n.reviewProgress(state.finished, state.total),
                  style: context.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppParams.spacing16.h),
          Expanded(
            child: SingleChildScrollView(
              child: _CardFace(
                card: card,
                revealed: state.revealed,
                onReveal: notifier.reveal,
              ),
            ),
          ),
          SizedBox(height: AppParams.spacing16.h),
          if (state.revealed)
            _GradeButtons(card: card, onGrade: notifier.grade)
          else
            AppPlatformElevatedButton(
              onPressed: notifier.reveal,
              text: l10n.reviewShowAnswer,
            ),
          SizedBox(height: AppParams.spacing16.h),
        ],
      ),
    );
  }
}

/// The card: prompt, and the answer once revealed.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.card,
    required this.revealed,
    required this.onReveal,
  });

  final ReviewCard card;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppParams.radiusCard.r);
    return Semantics(
      button: !revealed,
      hint: revealed ? null : l10n.reviewTapToReveal,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: radius,
        child: InkWell(
          onTap: revealed ? null : onReveal,
          borderRadius: radius,
          child: Container(
            constraints: BoxConstraints(
              minHeight: AppParams.reviewCardMinHeight.h,
            ),
            padding: EdgeInsets.all(AppParams.spacing24.r),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.languageName(card.promptLang),
                  style: context.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppParams.spacing8.h),
                Text(
                  card.prompt,
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (revealed) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppParams.spacing16.h,
                    ),
                    child: Divider(height: 1, color: scheme.outlineVariant),
                  ),
                  Text(
                    l10n.languageName(card.answerLang),
                    style: context.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: AppParams.spacing8.h),
                  Text(
                    card.answer,
                    style: context.textTheme.titleLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ] else ...[
                  SizedBox(height: AppParams.spacing24.h),
                  Text(
                    l10n.reviewTapToReveal,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Again / Hard / Good / Easy, each with the interval it leads to.
class _GradeButtons extends StatelessWidget {
  const _GradeButtons({required this.card, required this.onGrade});

  final ReviewCard card;
  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    const scheduler = Sm2Scheduler();
    String label(ReviewGrade grade) => switch (grade) {
      ReviewGrade.again => l10n.reviewAgain,
      ReviewGrade.hard => l10n.reviewHard,
      ReviewGrade.good => l10n.reviewGood,
      ReviewGrade.easy => l10n.reviewEasy,
    };
    return Wrap(
      spacing: AppParams.spacing8.w,
      runSpacing: AppParams.spacing8.h,
      alignment: WrapAlignment.center,
      children: [
        for (final grade in ReviewGrade.values)
          AppPlatformOutlinedButton(
            onPressed: () => onGrade(grade),
            text: l10n.reviewGradeButton(
              label(grade),
              l10n.reviewIntervalDays(
                scheduler.answer(card.state, grade).intervalDays,
              ),
            ),
          ),
      ],
    );
  }
}

/// End of the session, or nothing due when it opened.
class _Done extends StatelessWidget {
  const _Done({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final empty = state.total == 0;
    return ListView(
      padding: EdgeInsets.symmetric(vertical: AppParams.spacing24.h),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
          child: Column(
            children: [
              AppIcon(AppIcons.reviewCards, size: 48, color: scheme.primary),
              SizedBox(height: AppParams.spacing16.h),
              Text(
                empty ? l10n.reviewEmptyTitle : l10n.reviewDoneTitle,
                textAlign: TextAlign.center,
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: AppParams.spacing8.h),
              Text(
                empty ? l10n.reviewEmptyBody : l10n.reviewDoneBody(state.total),
                textAlign: TextAlign.center,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppParams.spacing24.h),
        const ReminderSettings(),
      ],
    );
  }
}

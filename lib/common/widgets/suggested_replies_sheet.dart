import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/learning/learning_assistant.dart';
import '../../core/learning/learning_models.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_circular_progress_indicator.dart';
import 'app_platform_outlined_button.dart';

/// Shows three suggested replies in [replyLang] with back-translations; [onPick] runs for the tapped one (F-19).
Future<void> showSuggestedRepliesSheet(
  BuildContext context, {
  required List<LearningLine> recent,
  required String replyLang,
  required String userLang,
  required String pickHint,
  required Future<void> Function(SuggestedReply reply) onPick,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppParams.radiusSheet.r),
    ),
  ),
  builder: (_) => SuggestedRepliesSheet(
    recent: recent,
    replyLang: replyLang,
    userLang: userLang,
    pickHint: pickHint,
    onPick: onPick,
  ),
);

/// Loads and lists suggested replies; tapping one closes the sheet and runs [onPick].
class SuggestedRepliesSheet extends ConsumerStatefulWidget {
  const SuggestedRepliesSheet({
    super.key,
    required this.recent,
    required this.replyLang,
    required this.userLang,
    required this.pickHint,
    required this.onPick,
  });

  final List<LearningLine> recent;
  final String replyLang;
  final String userLang;
  final String pickHint;
  final Future<void> Function(SuggestedReply reply) onPick;

  @override
  ConsumerState<SuggestedRepliesSheet> createState() =>
      _SuggestedRepliesSheetState();
}

class _SuggestedRepliesSheetState extends ConsumerState<SuggestedRepliesSheet> {
  late Future<List<SuggestedReply>> _replies = _load();

  /// Asks the assistant for replies.
  Future<List<SuggestedReply>> _load() => ref
      .read(learningAssistantProvider)
      .suggestReplies(
        recent: widget.recent,
        replyLang: widget.replyLang,
        userLang: widget.userLang,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppParams.spacing20.w,
          0,
          AppParams.spacing20.w,
          AppParams.spacing16.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.learningSuggestReply,
              style: context.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            Text(
              widget.pickHint,
              style: context.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: AppParams.spacing12.h),
            FutureBuilder<List<SuggestedReply>>(
              future: _replies,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Padding(
                    padding: EdgeInsets.all(AppParams.spacing24.r),
                    child: Center(
                      child: AppCircularProgressIndicator(
                        color: scheme.primary,
                      ),
                    ),
                  );
                }
                final replies = snapshot.data ?? const [];
                if (snapshot.hasError || replies.isEmpty) {
                  return Column(
                    children: [
                      Text(
                        l10n.learningFailed,
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: AppParams.spacing12.h),
                      AppPlatformOutlinedButton(
                        onPressed: () => setState(() => _replies = _load()),
                        text: l10n.learningRetry,
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final reply in replies)
                      Padding(
                        padding: EdgeInsets.only(bottom: AppParams.spacing8.h),
                        child: _ReplyTile(
                          reply: reply,
                          onTap: () async {
                            Navigator.of(context).pop();
                            await widget.onPick(reply);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One reply with its back-translation.
class _ReplyTile extends StatelessWidget {
  const _ReplyTile({required this.reply, required this.onTap});

  final SuggestedReply reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppParams.radiusCard.r);
    return Semantics(
      button: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.all(AppParams.spacing16.r),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.text,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (reply.backTranslation.isNotEmpty)
                  Text(
                    reply.backTranslation,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

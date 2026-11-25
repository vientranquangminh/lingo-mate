import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/widgets/caption_scale.dart';
import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_circular_progress_indicator.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_dialog.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_input_dialog.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../common/widgets/engine_badge.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../data/notifier/history_providers.dart';
import '../widget/history_format.dart';

/// Transcript screen S-10: title, date, duration, engines used and every line, with rename, share and delete (F-07).
class TranscriptPage extends ConsumerWidget {
  const TranscriptPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final detail = ref.watch(transcriptProvider(sessionId));
    return AppPlatformScaffold(
      body: SafeArea(
        child: detail.when(
          loading: () => Center(
            child: AppCircularProgressIndicator(color: scheme.primary),
          ),
          error: (_, _) => _Missing(text: l10n.transcriptMissing),
          data: (value) => value == null
              ? _Missing(text: l10n.transcriptMissing)
              : _Transcript(detail: value),
        ),
      ),
    );
  }
}

/// The loaded transcript.
class _Transcript extends ConsumerWidget {
  const _Transcript({required this.detail});

  final SessionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final session = detail.session;
    final title = session.title ?? l10n.historyUntitled;
    final main = detail.mainEngine;
    final started = session.startedAt;
    final meta = [
      '${HistoryFormat.dayLabel(l10n, locale, started, DateTime.now())}, '
          '${DateFormat.Hm(locale).format(started)}',
      HistoryFormat.duration(l10n, session.durationSec),
      '${l10n.languageName(session.langA)} ⇄ ${l10n.languageName(session.langB)}',
    ].join(' · ');
    final engineSeconds = detail.engineSeconds.entries.toList()
      ..sort((a, b) => b.value - a.value);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
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
                const Spacer(),
                AppCircleIconButton(
                  icon: AppIcons.edit,
                  semanticLabel: l10n.transcriptRename,
                  borderColor: Colors.transparent,
                  onPressed: () => _rename(context, ref, title),
                ),
                AppCircleIconButton(
                  icon: AppIcons.share,
                  semanticLabel: l10n.transcriptShare,
                  borderColor: Colors.transparent,
                  onPressed: () => ref
                      .read(systemSettingsProvider)
                      .shareText(
                        SessionRepository.plainText(detail, title: title),
                        subject: title,
                      ),
                ),
                AppCircleIconButton(
                  icon: AppIcons.delete,
                  semanticLabel: l10n.transcriptDelete,
                  color: scheme.error,
                  borderColor: Colors.transparent,
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppParams.spacing20.w),
          sliver: SliverList.list(
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              SizedBox(height: AppParams.spacing8.h),
              Text(
                meta,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppParams.spacing12.h),
              Wrap(
                spacing: AppParams.spacing8.w,
                runSpacing: AppParams.spacing8.h,
                children: [
                  for (final entry in engineSeconds)
                    EngineBadge(
                      engine: entry.key,
                      label: l10n.transcriptEngineMinutes(
                        HistoryFormat.engineName(l10n, entry.key),
                        HistoryFormat.duration(l10n, entry.value),
                      ),
                    ),
                ],
              ),
              SizedBox(height: AppParams.spacing16.h),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
          sliver: SliverList.builder(
            itemCount: detail.utterances.length,
            itemBuilder: (context, i) => CaptionScale(
              child: _Line(
                utterance: detail.utterances[i],
                startedAt: started,
                mainEngine: main,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Asks for a new title and saves it.
  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final l10n = context.localization;
    final title = await showAppTextInputDialog(
      context: context,
      title: l10n.transcriptRenameTitle,
      initialValue: current,
      confirm: l10n.commonSave,
      cancel: l10n.commonCancel,
    );
    if (title == null) {
      return;
    }
    await ref.read(sessionRepositoryProvider).rename(detail.session.id, title);
    ref.invalidate(transcriptProvider(detail.session.id));
  }

  /// Deletes the session after confirmation and closes the screen (AC-07.4).
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final confirmed = await showAppPlatformDialog(
      context: context,
      title: l10n.transcriptDeleteTitle,
      body: l10n.transcriptDeleteBody,
      confirm: l10n.transcriptDelete,
      cancel: l10n.commonCancel,
      destructive: true,
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(sessionRepositoryProvider).delete(detail.session.id);
    if (context.mounted) {
      await Navigator.of(context).maybePop();
    }
  }
}

/// One utterance: time, translation, original, and an engine badge when it differs from the main engine (AC-07.2).
class _Line extends ConsumerWidget {
  const _Line({
    required this.utterance,
    required this.startedAt,
    required this.mainEngine,
  });

  final Utterance utterance;
  final DateTime startedAt;
  final EngineKind? mainEngine;

  /// Offers Save to phrasebook and Copy for this line (F-07, AC-08.1).
  void _actions(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final translated = utterance.targetText.isNotEmpty;
    showAppActionSheet(
      context: context,
      title: l10n.bubbleActions,
      cancel: l10n.commonCancel,
      actions: [
        if (translated)
          AppSheetAction(
            icon: AppIcons.bookmark,
            label: l10n.phraseSave,
            onSelected: () async {
              await saveToPhrasebook(
                context,
                ref,
                source: 'transcript',
                sourceLang: utterance.sourceLang,
                sourceText: utterance.sourceText,
                targetLang: utterance.targetLang,
                targetText: utterance.targetText,
                fromUtteranceId: utterance.id,
              );
              ref.invalidate(transcriptProvider(utterance.sessionId));
            },
          ),
        AppSheetAction(
          icon: AppIcons.copy,
          label: l10n.bubbleCopy,
          onSelected: () async {
            await Clipboard.setData(
              ClipboardData(
                text: translated
                    ? '${utterance.sourceText}\n${utterance.targetText}'
                    : utterance.sourceText,
              ),
            );
            if (context.mounted) {
              showAppToast(context, l10n.bubbleCopied);
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final engine = UtteranceEngine.parse(utterance.engine);
    final time = DateFormat.Hm(locale)
        .format(startedAt.add(Duration(milliseconds: utterance.startMs)));
    final partner = utterance.speaker == 'b';
    final badge = switch (engine) {
      UtteranceEngine.offlineFallback => l10n.transcriptFallback,
      UtteranceEngine.none => null,
      _ when engine.kind != mainEngine => HistoryFormat.engineName(
        l10n,
        engine.kind!,
      ),
      _ => null,
    };
    final translated = utterance.targetText.isNotEmpty;
    final saved = utterance.isSaved;
    return InkWell(
      onLongPress: () => _actions(context, ref),
      child: Container(
        color: partner ? scheme.surfaceContainerHigh : null,
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing20.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: 44.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    softWrap: false,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (saved) ...[
                    SizedBox(height: AppParams.spacing4.h),
                    AppIcon(
                      AppIcons.bookmarkFilled,
                      size: 16,
                      color: scheme.primary,
                      semanticLabel: l10n.phraseSaved,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: AppParams.spacing8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translated ? utterance.targetText : utterance.sourceText,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: AppParams.spacing4.h),
                  Text(
                    translated
                        ? utterance.sourceText
                        : l10n.transcriptNotTranslated,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (badge != null && engine.kind != null) ...[
                    SizedBox(height: AppParams.spacing8.h),
                    EngineBadge(engine: engine.kind!, label: badge),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the session was deleted or never existed.
class _Missing extends StatelessWidget {
  const _Missing({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: context.textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

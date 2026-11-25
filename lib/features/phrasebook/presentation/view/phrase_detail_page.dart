import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_input_dialog.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/phrases/phrase_repository.dart';
import '../../../../navigation/route_const.dart';
import '../../data/notifier/phrasebook_providers.dart';

/// Phrase detail S-12: both sides with play, note, tags, source session, show large, favourite and delete (F-08).
class PhraseDetailPage extends ConsumerWidget {
  const PhraseDetailPage({super.key, required this.phraseId});

  final String phraseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final item = ref.watch(phraseProvider(phraseId)).value;
    final repo = ref.read(phraseRepositoryProvider);
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: item == null
            ? const SizedBox.shrink()
            : ListView(
                padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
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
                        const Spacer(),
                        AppCircleIconButton(
                          icon: item.phrase.favorite
                              ? AppIcons.starFilled
                              : AppIcons.star,
                          semanticLabel: item.phrase.favorite
                              ? l10n.phraseUnfavorite
                              : l10n.phraseFavorite,
                          selected: item.phrase.favorite,
                          color: item.phrase.favorite ? scheme.primary : null,
                          borderColor: Colors.transparent,
                          onPressed: () =>
                              repo.setFavorite(phraseId, !item.phrase.favorite),
                        ),
                        AppCircleIconButton(
                          icon: AppIcons.delete,
                          semanticLabel: l10n.phraseDelete,
                          color: scheme.error,
                          borderColor: Colors.transparent,
                          onPressed: () => _delete(context, ref),
                        ),
                      ],
                    ),
                  ),
                  _Side(
                    lang: item.phrase.sourceLang,
                    text: item.phrase.sourceText,
                    background: scheme.surfaceContainerLowest,
                    foreground: scheme.onSurface,
                  ),
                  _Side(
                    lang: item.phrase.targetLang,
                    text: item.phrase.targetText,
                    background: scheme.inverseSurface,
                    foreground: scheme.onInverseSurface,
                    onEdit: () => _editTranslation(context, ref, item.phrase),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppParams.spacing20.w,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (item.sessionId != null) ...[
                          SizedBox(height: AppParams.spacing8.h),
                          InkWell(
                            onTap: () => context.pushNamed(
                              AppRouteName.transcript,
                              pathParameters: {'id': item.sessionId!},
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppParams.spacing12.h,
                              ),
                              child: Row(
                                children: [
                                  AppIcon(
                                    AppIcons.navHistory,
                                    size: 20,
                                    color: scheme.primary,
                                  ),
                                  SizedBox(width: AppParams.spacing8.w),
                                  Expanded(
                                    child: Text(
                                      l10n.phraseFrom(
                                        item.sessionTitle ??
                                            l10n.historyUntitled,
                                        item.spokenAt == null
                                            ? ''
                                            : DateFormat.Hm(
                                                Localizations.localeOf(context)
                                                    .toLanguageTag(),
                                              ).format(item.spokenAt!),
                                      ),
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(color: scheme.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        _SectionTitle(l10n.phraseNote),
                        InkWell(
                          onTap: () => _editNote(context, ref, item.phrase),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppParams.spacing8.h,
                            ),
                            child: Text(
                              item.phrase.note ?? l10n.phraseAddNote,
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: item.phrase.note == null
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                        _SectionTitle(l10n.phraseTags),
                        Wrap(
                          spacing: AppParams.spacing8.w,
                          runSpacing: AppParams.spacing8.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final tag in item.tags)
                              _TagChip(
                                tag: tag,
                                onRemove: () =>
                                    repo.removeTag(phraseId, tag.id),
                              ),
                            AppPlatformTextButton(
                              onPressed: () => _addTag(context, ref),
                              text: '+ ${l10n.phraseAddTag}',
                            ),
                          ],
                        ),
                        SizedBox(height: AppParams.spacing24.h),
                        AppPlatformOutlinedButton(
                          onPressed: () => context.pushNamed(
                            AppRouteName.showMode,
                            extra: <String, String?>{
                              'text': item.phrase.targetText,
                              'original': item.phrase.sourceText,
                            },
                          ),
                          text: l10n.phraseShowLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Soft-deletes the phrase, closes the screen and offers Undo for 5 s (AC-08.6).
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final repo = ref.read(phraseRepositoryProvider);
    await repo.softDelete(phraseId);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      l10n.phraseDeleted,
      actionLabel: l10n.commonUndo,
      onAction: () => repo.restore(phraseId),
    );
    await Navigator.of(context).maybePop();
  }

  /// Edits the translation.
  Future<void> _editTranslation(
    BuildContext context,
    WidgetRef ref,
    Phrase phrase,
  ) async {
    final l10n = context.localization;
    final text = await showAppTextInputDialog(
      context: context,
      title: l10n.phraseEditTranslation,
      initialValue: phrase.targetText,
      confirm: l10n.commonSave,
      cancel: l10n.commonCancel,
    );
    if (text != null && text.trim().isNotEmpty) {
      await ref.read(phraseRepositoryProvider).edit(phraseId, targetText: text);
    }
  }

  /// Edits the note.
  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    Phrase phrase,
  ) async {
    final l10n = context.localization;
    final text = await showAppTextInputDialog(
      context: context,
      title: l10n.phraseNote,
      initialValue: phrase.note ?? '',
      confirm: l10n.commonSave,
      cancel: l10n.commonCancel,
    );
    if (text != null) {
      await ref.read(phraseRepositoryProvider).edit(phraseId, note: text);
    }
  }

  /// Asks for a tag name and adds it.
  Future<void> _addTag(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final name = await showAppTextInputDialog(
      context: context,
      title: l10n.phraseAddTag,
      initialValue: '',
      confirm: l10n.commonSave,
      cancel: l10n.commonCancel,
    );
    if (name != null) {
      await ref.read(phraseRepositoryProvider).addTag(phraseId, name);
    }
  }
}

/// One side of the phrase: language, text large, play.
class _Side extends ConsumerWidget {
  const _Side({
    required this.lang,
    required this.text,
    required this.background,
    required this.foreground,
    this.onEdit,
  });

  final String lang;
  final String text;
  final Color background;
  final Color foreground;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppParams.spacing20.w,
        vertical: AppParams.spacing8.h,
      ),
      padding: EdgeInsets.all(AppParams.spacing20.r),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.languageName(lang),
                  style: context.textTheme.labelLarge?.copyWith(
                    color: foreground.withValues(alpha: 0.72),
                  ),
                ),
                SizedBox(height: AppParams.spacing8.h),
                GestureDetector(
                  onTap: onEdit,
                  child: Text(
                    text,
                    style: context.textTheme.headlineSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppParams.spacing8.w),
          Column(
            children: [
              AppCircleIconButton(
                icon: AppIcons.speaker,
                semanticLabel: l10n.phrasesPlay(l10n.languageName(lang)),
                color: foreground,
                borderColor: foreground.withValues(alpha: 0.4),
                onPressed: () =>
                    ref.read(speechSynthesizerProvider).speak(text, lang: lang),
              ),
              if (onEdit != null) ...[
                SizedBox(height: AppParams.spacing8.h),
                AppCircleIconButton(
                  icon: AppIcons.edit,
                  semanticLabel: l10n.phraseEditTranslation,
                  color: foreground,
                  borderColor: Colors.transparent,
                  onPressed: onEdit,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Small upper-case heading.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppParams.spacing16.h,
        bottom: AppParams.spacing4.h,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: context.textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A tag with a remove button.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.onRemove});

  final Tag tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: AppParams.spacing12.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.name,
              style: context.textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            AppCircleIconButton(
              icon: AppIcons.close,
              semanticLabel: context.localization.phraseRemoveTag(tag.name),
              color: scheme.onPrimaryContainer,
              borderColor: Colors.transparent,
              size: 36,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

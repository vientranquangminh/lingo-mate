import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_dialog.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_input_dialog.dart';
import '../../../../common/widgets/settings_toggle_rows.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/glossary/glossary_repository.dart';
import '../widget/glossary_header.dart';
import '../widget/term_sheet.dart';

/// S-22 terms of one glossary set: term, translation and note; add, edit, delete, "Use in sessions" (AC-18.1).
class GlossarySetPage extends ConsumerWidget {
  const GlossarySetPage({super.key, required this.setId});

  final String setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final set = ref.watch(glossarySetProvider(setId)).value;
    final terms = ref.watch(glossaryTermsProvider(setId)).value ?? const [];
    final repository = ref.read(glossaryRepositoryProvider);
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlossaryHeader(
              title: set?.name ?? '',
              actions: [
                AppCircleIconButton(
                  icon: AppIcons.add,
                  semanticLabel: l10n.glossaryAddTerm,
                  borderColor: Colors.transparent,
                  onPressed: () async {
                    final input = await showTermSheet(context);
                    if (input != null) {
                      await repository.addTerm(
                        setId,
                        term: input.term,
                        translation: input.translation,
                        note: input.note,
                      );
                    }
                  },
                ),
                AppCircleIconButton(
                  icon: AppIcons.more,
                  semanticLabel: l10n.glossarySetActions,
                  borderColor: Colors.transparent,
                  onPressed: set == null
                      ? null
                      : () => _setActions(context, ref, set),
                ),
              ],
            ),
            if (set != null)
              SettingsSwitchRow(
                label: l10n.glossaryUseInSessions,
                description: l10n.glossaryUseInSessionsDescription,
                value: set.active,
                onChanged: (on) => repository.setActive(setId, on),
              ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: terms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppParams.spacing24.r),
                        child: Text(
                          l10n.glossaryNoTerms,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
                      itemCount: terms.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: AppParams.spacing20.w,
                        endIndent: AppParams.spacing20.w,
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder: (context, i) => _TermRow(term: terms[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Offers Rename and Delete for the set.
  void _setActions(BuildContext context, WidgetRef ref, GlossarySet set) {
    final l10n = context.localization;
    final repository = ref.read(glossaryRepositoryProvider);
    showAppActionSheet(
      context: context,
      title: set.name,
      cancel: l10n.commonCancel,
      actions: [
        AppSheetAction(
          icon: AppIcons.edit,
          label: l10n.glossaryRenameSet,
          onSelected: () async {
            final name = await showAppTextInputDialog(
              context: context,
              title: l10n.glossaryRenameSet,
              initialValue: set.name,
              confirm: l10n.commonSave,
              cancel: l10n.commonCancel,
            );
            if (name != null && name.trim().isNotEmpty) {
              await repository.renameSet(set.id, name);
            }
          },
        ),
        AppSheetAction(
          icon: AppIcons.delete,
          label: l10n.glossaryDeleteSet,
          onSelected: () async {
            final confirmed = await showAppPlatformDialog(
              context: context,
              title: l10n.glossaryDeleteSetTitle,
              body: l10n.glossaryDeleteSetBody,
              confirm: l10n.glossaryDeleteSet,
              cancel: l10n.commonCancel,
              destructive: true,
            );
            if (confirmed == true) {
              await repository.deleteSet(set.id);
              if (context.mounted) {
                await Navigator.of(context).maybePop();
              }
            }
          },
        ),
      ],
    );
  }
}

/// One term: term, preferred translation and note; tap to edit, long-press to delete.
class _TermRow extends ConsumerWidget {
  const _TermRow({required this.term});

  final GlossaryTerm term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final repository = ref.read(glossaryRepositoryProvider);
    final note = term.note;
    return InkWell(
      onTap: () async {
        final input = await showTermSheet(
          context,
          initial: TermInput(
            term: term.term,
            translation: term.translation,
            note: term.note,
          ),
        );
        if (input != null) {
          await repository.editTerm(
            term.id,
            term: input.term,
            translation: input.translation,
            note: input.note,
          );
        }
      },
      onLongPress: () => showAppActionSheet(
        context: context,
        title: term.term,
        cancel: l10n.commonCancel,
        actions: [
          AppSheetAction(
            icon: AppIcons.delete,
            label: l10n.glossaryDeleteTerm,
            onSelected: () => repository.deleteTerm(term.id),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing20.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              term.term,
              style: context.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            Text(
              term.translation,
              style: context.textTheme.bodyLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            if (note != null)
              Text(
                note,
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_switch.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_input_dialog.dart';
import '../../../../core/glossary/glossary_repository.dart';
import '../../../../navigation/route_const.dart';
import '../widget/glossary_header.dart';

/// S-22 Glossary: sets with their term counts and the "Use in sessions" switch (F-18).
class GlossaryPage extends ConsumerWidget {
  const GlossaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final sets = ref.watch(glossarySetsProvider).value;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlossaryHeader(
              title: l10n.glossaryTitle,
              actions: [
                AppCircleIconButton(
                  icon: AppIcons.add,
                  semanticLabel: l10n.glossaryNewSet,
                  borderColor: Colors.transparent,
                  onPressed: () => _create(context, ref),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppParams.spacing20.w,
                vertical: AppParams.spacing8.h,
              ),
              child: Text(
                l10n.glossaryIntro,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: sets == null
                  ? const SizedBox.shrink()
                  : sets.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppParams.spacing24.r),
                        child: Text(
                          l10n.glossaryEmpty,
                          textAlign: TextAlign.center,
                          style: context.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: sets.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: AppParams.spacing20.w,
                        endIndent: AppParams.spacing20.w,
                        color: scheme.outlineVariant,
                      ),
                      itemBuilder: (context, i) => _SetRow(item: sets[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks for a name, creates the set and opens it.
  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = context.localization;
    final name = await showAppTextInputDialog(
      context: context,
      title: l10n.glossaryNewSet,
      initialValue: '',
      confirm: l10n.commonSave,
      cancel: l10n.commonCancel,
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final id = await ref.read(glossaryRepositoryProvider).createSet(name);
    if (context.mounted) {
      await context.pushNamed(
        AppRouteName.glossarySet,
        pathParameters: {'id': id},
      );
    }
  }
}

/// A set: name, term count and the "Use in sessions" switch.
class _SetRow extends ConsumerWidget {
  const _SetRow({required this.item});

  final GlossarySetSummary item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final set = item.set;
    return InkWell(
      onTap: () => context.pushNamed(
        AppRouteName.glossarySet,
        pathParameters: {'id': set.id},
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing20.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.glossary, color: scheme.primary),
            SizedBox(width: AppParams.spacing16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    set.name,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    [
                      l10n.glossaryTermCount(item.termCount),
                      if (set.active) l10n.glossaryInUse,
                    ].join(' · '),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: l10n.glossaryUseInSessions,
              child: AppPlatformSwitch(
                value: set.active,
                onChanged: (on) =>
                    ref.read(glossaryRepositoryProvider).setActive(set.id, on),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/widgets/app_empty_state.dart';
import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_search_field.dart';
import '../../../../common/widgets/app_segmented_control.dart';
import '../../../../common/widgets/app_selectable_chip.dart';
import '../../../../common/widgets/review_banner.dart';
import '../../../../core/phrases/phrase_repository.dart';
import '../../../../core/review/review_repository.dart';
import '../../../../core/review/review_settings.dart';
import '../../../../navigation/route_const.dart';
import '../../data/notifier/phrasebook_providers.dart';
import '../widget/phrase_row.dart';
import '../widget/quick_tab.dart';

/// Which half of the Phrases tab is open.
enum PhrasesTab { quick, mine }

/// Phrases tab: `Quick | Mine`; Mine is the phrasebook S-11 (F-08).
class PhrasesPage extends ConsumerStatefulWidget {
  const PhrasesPage({super.key, this.initialTab = PhrasesTab.mine});

  final PhrasesTab initialTab;

  @override
  ConsumerState<PhrasesPage> createState() => _PhrasesPageState();
}

class _PhrasesPageState extends ConsumerState<PhrasesPage> {
  final _search = TextEditingController();
  late PhrasesTab _tab = widget.initialTab;
  PhraseFilter _filter = const PhraseFilter();

  @override
  void didUpdateWidget(PhrasesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      floatingActionButton: _tab == PhrasesTab.mine
          ? _AddButton(
              label: l10n.phrasesAdd,
              onTap: () => context.pushNamed(AppRouteName.addPhrase),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppParams.spacing20.w,
                AppParams.spacing16.h,
                AppParams.spacing20.w,
                AppParams.spacing12.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.navPhrases,
                      style: context.textTheme.headlineMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(height: AppParams.spacing12.h),
                  AppSegmentedControl<PhrasesTab>(
                    segments: {
                      PhrasesTab.quick: l10n.phrasesQuick,
                      PhrasesTab.mine: l10n.phrasesMine,
                    },
                    selected: _tab,
                    onChanged: (tab) => setState(() => _tab = tab),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == PhrasesTab.quick
                  ? const QuickTab()
                  : _Mine(
                      search: _search,
                      filter: _filter,
                      onFilter: (f) => setState(() => _filter = f),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phrasebook: search, filter chips and the list.
class _Mine extends ConsumerWidget {
  const _Mine({
    required this.search,
    required this.filter,
    required this.onFilter,
  });

  final TextEditingController search;
  final PhraseFilter filter;
  final ValueChanged<PhraseFilter> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(phraseCountProvider).value ?? 0;
    final pairs = ref.watch(phrasePairsProvider).value ?? const [];
    final tags = ref.watch(phraseTagsProvider).value ?? const [];
    final items = ref.watch(phrasesProvider(filter)).value;
    final unfiltered =
        filter.pair == null &&
        filter.tagId == null &&
        !filter.favoritesOnly &&
        filter.query.trim().isEmpty;
    final due = ref.watch(reviewDueCountProvider).value ?? 0;
    final streak = ref.watch(
      reviewSettingsProvider.select((s) => s.streakOn(DateTime.now())),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (due > 0)
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppParams.spacing20.w,
              0,
              AppParams.spacing20.w,
              AppParams.spacing12.h,
            ),
            child: ReviewBanner(
              count: due,
              label: l10n.reviewBannerCards(due),
              streak: streak > 0 ? l10n.reviewStreak(streak) : null,
              onTap: () => context.pushNamed(AppRouteName.review),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppParams.spacing20.w),
          child: AppSearchField(
            controller: search,
            hint: l10n.phrasesSearchHint(count),
            clearLabel: l10n.historyClearSearch,
            onChanged: (q) => onFilter(filter.copyWith(query: q)),
          ),
        ),
        SizedBox(height: AppParams.spacing12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppParams.spacing20.w),
          child: Row(
            children: [
              AppSelectableChip(
                label: l10n.phrasesFilterAll,
                selected:
                    filter.pair == null &&
                    filter.tagId == null &&
                    !filter.favoritesOnly,
                onChanged: (_) => onFilter(PhraseFilter(query: filter.query)),
              ),
              for (final pair in pairs) ...[
                SizedBox(width: AppParams.spacing8.w),
                AppSelectableChip(
                  label: '${pair.a.toUpperCase()} ⇄ ${pair.b.toUpperCase()}',
                  selected: filter.pair == pair,
                  onChanged: (on) =>
                      onFilter(filter.copyWith(pair: () => on ? pair : null)),
                ),
              ],
              for (final tag in tags) ...[
                SizedBox(width: AppParams.spacing8.w),
                AppSelectableChip(
                  label: tag.name,
                  selected: filter.tagId == tag.id,
                  onChanged: (on) => onFilter(
                    filter.copyWith(tagId: () => on ? tag.id : null),
                  ),
                ),
              ],
              SizedBox(width: AppParams.spacing8.w),
              AppSelectableChip(
                label: '★ ${l10n.phrasesFilterFavorites}',
                selected: filter.favoritesOnly,
                onChanged: (on) => onFilter(filter.copyWith(favoritesOnly: on)),
              ),
            ],
          ),
        ),
        SizedBox(height: AppParams.spacing8.h),
        Expanded(
          child: items == null
              ? const SizedBox.shrink()
              : items.isEmpty
              ? _Message(
                  unfiltered ? l10n.phrasesEmpty : l10n.phrasesNoMatch,
                  icon: unfiltered ? AppIcons.bookmark : AppIcons.search,
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: 96.h),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: AppParams.spacing20.w,
                    endIndent: AppParams.spacing20.w,
                    color: scheme.outlineVariant,
                  ),
                  itemBuilder: (context, i) => PhraseRow(
                    item: items[i],
                    onTap: () => context.pushNamed(
                      AppRouteName.phrase,
                      pathParameters: {'id': items[i].phrase.id},
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// The round "+" button that adds a phrase.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: scheme.primary,
        elevation: 1,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing20.w,
              vertical: AppParams.spacing16.h,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.add, size: 22, color: scheme.onPrimary),
                SizedBox(width: AppParams.spacing8.w),
                Text(
                  label,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary,
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

/// A calm empty state with [icon] above [text].
class _Message extends StatelessWidget {
  const _Message(this.text, {this.icon = AppIcons.bookmark});

  final String text;
  final AppIcons icon;

  @override
  Widget build(BuildContext context) =>
      AppEmptyState(icon: icon, message: text);
}

import '../../../../common/widgets/app_skeleton.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_colors.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_search_field.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../../../navigation/route_const.dart';
import '../../data/notifier/history_providers.dart';
import '../widget/history_format.dart';

/// History screen S-09: finished sessions grouped by day, with search across transcripts (F-07).
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final searching = SessionRepository.ftsQuery(_query) != null;
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.historyTitle)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppParams.spacing16.w,
              AppParams.spacing8.h,
              AppParams.spacing16.w,
              AppParams.spacing8.h,
            ),
            child: AppSearchField(
              controller: _search,
              hint: l10n.historySearchHint,
              clearLabel: l10n.historyClearSearch,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: searching
                ? _SearchResults(query: _query.trim())
                : const _SessionList(),
          ),
        ],
      ),
    );
  }
}

/// Sessions grouped under Today, Yesterday and dates.
class _SessionList extends ConsumerWidget {
  const _SessionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final sessions = ref.watch(historySessionsProvider);
    return sessions.when(
      loading: () => const AppSkeletonList(),
      error: (_, _) => _Message(l10n.historyEmpty),
      data: (items) {
        if (items.isEmpty) {
          return _Message(l10n.historyEmpty);
        }
        final now = DateTime.now();
        final children = <Widget>[];
        String? lastLabel;
        for (final item in items) {
          final label = HistoryFormat.dayLabel(
            l10n,
            locale,
            item.session.startedAt,
            now,
          );
          if (label != lastLabel) {
            children.add(_DayHeader(label));
            lastLabel = label;
          }
          children.add(_SessionRow(summary: item));
        }
        return ListView(
          padding: EdgeInsets.only(bottom: AppParams.spacing24.h),
          children: children,
        );
      },
    );
  }
}

/// Utterances matching the query, each opening its transcript.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final hits = ref.watch(historySearchProvider(query));
    final items = hits.value;
    if (items == null) {
      return const SizedBox.shrink();
    }
    if (items.isEmpty) {
      return _Message(l10n.historyNoResults(query));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: scheme.outlineVariant),
      itemBuilder: (context, i) {
        final hit = items[i];
        final u = hit.utterance;
        return InkWell(
          onTap: () => context.pushNamed(
            AppRouteName.transcript,
            pathParameters: {'id': hit.session.id},
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing16.w,
              vertical: AppParams.spacing12.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hit.session.title ?? l10n.historyUntitled,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: AppParams.spacing4.h),
                if (u.targetText.isNotEmpty)
                  Text(
                    u.targetText,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                Text(
                  u.sourceText,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Day group heading.
class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppParams.spacing16.w,
        AppParams.spacing16.h,
        AppParams.spacing16.w,
        AppParams.spacing4.h,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: context.textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// One session: mode icon, title, pair, duration, engine dots and first line.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final session = summary.session;
    final engines = [
      if (session.standardSec > 0) EngineKind.standard,
      if (session.liveSec > 0) EngineKind.live,
      if (session.engineInitial.startsWith('offline') ||
          session.standardSec + session.liveSec == 0)
        EngineKind.offline,
    ];
    final firstLine = summary.firstLine;
    return InkWell(
      onTap: () => context.pushNamed(
        AppRouteName.transcript,
        pathParameters: {'id': session.id},
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing16.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: HistoryFormat.modeName(l10n, session.mode),
              child: AppIcon(
                HistoryFormat.modeIcon(session.mode),
                color: scheme.primary,
              ),
            ),
            SizedBox(width: AppParams.spacing12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title ?? l10n.historyUntitled,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: AppParams.spacing4.h),
                  Wrap(
                    spacing: AppParams.spacing8.w,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        HistoryFormat.pair(session.langA, session.langB),
                        style: context.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        HistoryFormat.duration(l10n, session.durationSec),
                        style: context.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      for (final engine in engines)
                        Semantics(
                          label: HistoryFormat.engineName(l10n, engine),
                          child: Container(
                            width: AppParams.engineDot.r,
                            height: AppParams.engineDot.r,
                            decoration: BoxDecoration(
                              color: context.appColors.engine(engine).dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (firstLine != null) ...[
                    SizedBox(height: AppParams.spacing4.h),
                    Text(
                      firstLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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

/// Centered note for empty states.
class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppParams.spacing24.r),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

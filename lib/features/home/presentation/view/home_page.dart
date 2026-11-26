import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/engine_chip.dart';
import '../../../../common/widgets/engine_sheet.dart';
import '../../../../common/widgets/quick_phrase_card.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/quick_phrases/quick_phrases.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../../../core/settings/user_settings.dart';
import '../../../../navigation/route_const.dart';
import '../../../meeting/data/notifier/meeting_notifier.dart';
import '../../../language_packs/data/model/pack_models.dart';
import '../../../language_packs/data/notifier/language_packs_notifier.dart';

/// The latest finished session, for the Continue card.
final latestSessionProvider = StreamProvider.autoDispose<SessionSummary?>(
  (ref) => ref
      .watch(sessionRepositoryProvider)
      .watchSessions()
      .map((all) => all.firstOrNull),
);

/// Translate home S-04: language pair, engine, the three modes, offline status and the last session.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final pair = ref.watch(userSettingsProvider.select((s) => s.pair));
    final selection = ref
        .watch(
          engineSelectionProvider(
            EngineRequest(mode: SessionMode.conversation, pair: pair),
          ),
        )
        .value;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: AppParams.spacing20.w,
            vertical: AppParams.spacing16.h,
          ),
          children: [
            Wrap(
              spacing: AppParams.spacing8.w,
              runSpacing: AppParams.spacing8.h,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PairPill(pair: pair),
                EngineChip(
                  engine: selection?.conversationEngine,
                  onTap: selection == null
                      ? null
                      : () async {
                          final choice = await showEngineSheet(
                            context: context,
                            current: selection.conversationEngine,
                            pinned: ref.read(enginePinProvider),
                            blocked: selection.blocked,
                          );
                          if (choice != null) {
                            ref
                                .read(enginePinProvider.notifier)
                                .pin(choice.engine);
                          }
                        },
                ),
              ],
            ),
            SizedBox(height: AppParams.spacing24.h),
            Semantics(
              header: true,
              child: Text(
                l10n.homeTitle,
                style: context.textTheme.headlineMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing20.h),
            _ConversationCard(
              onTap: () => context.pushNamed(
                AppRouteName.conversation,
                queryParameters: {'a': pair.a, 'b': pair.b},
              ),
            ),
            SizedBox(height: AppParams.spacing12.h),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ModeCard(
                      icon: AppIcons.modeListen,
                      title: l10n.homeListenTitle,
                      body: l10n.homeListenBody,
                      onTap: () => context.pushNamed(
                        AppRouteName.listen,
                        queryParameters: {'from': pair.b, 'to': pair.a},
                      ),
                    ),
                  ),
                  SizedBox(width: AppParams.spacing12.w),
                  Expanded(
                    child: _ModeCard(
                      icon: AppIcons.modeMeeting,
                      title: l10n.homeMeetingTitle,
                      body: ref.watch(meetingProvider.select((s) => s.running))
                          ? l10n.homeMeetingRunning
                          : l10n.homeMeetingBody,
                      onTap: () => context.pushNamed(AppRouteName.meeting),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppParams.spacing12.h),
            _ModeCard(
              horizontal: true,
              icon: AppIcons.modeMedia,
              title: l10n.homeMediaTitle,
              body: l10n.homeMediaBody,
              onTap: () => context.pushNamed(
                AppRouteName.listen,
                queryParameters: {'from': pair.b, 'to': pair.a, 'media': '1'},
              ),
            ),
            SizedBox(height: AppParams.spacing20.h),
            QuickFavoritesRow(
              pair: LanguagePair(
                ref.watch(quickSourceProvider),
                ref.watch(quickTargetProvider),
              ),
              title: l10n.homeFavoritePhrases,
              padding: 0,
              bottomSpacing: AppParams.spacing20,
              trailing: AppPlatformTextButton(
                onPressed: () => context.goNamed(
                  AppRouteName.phrases,
                  queryParameters: {'tab': 'quick'},
                ),
                text: l10n.homeSeeAll,
              ),
            ),
            _OfflineCard(pair: pair),
            SizedBox(height: AppParams.spacing12.h),
            const _ContinueCard(),
          ],
        ),
      ),
    );
  }
}

/// `English ⇄ Vietnamese`: tap a language to change it, the arrows to swap.
class _PairPill extends ConsumerWidget {
  const _PairPill({required this.pair});

  final LanguagePair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.read(userSettingsProvider.notifier);

    /// Opens the language list and replaces side [a] or b.
    Future<void> pick({required bool a}) async {
      final matrix = await ref.read(capabilityMatrixProvider.future);
      if (!context.mounted) {
        return;
      }
      final other = a ? pair.b : pair.a;
      await showAppActionSheet(
        context: context,
        title: l10n.homePickLanguage,
        cancel: l10n.commonCancel,
        actions: [
          for (final language in matrix.languages.values)
            if (language.code != other)
              AppSheetAction(
                icon: AppIcons.language,
                label: language.name == l10n.languageName(language.code)
                    ? language.name
                    : '${l10n.languageName(language.code)} · ${language.name}',
                onSelected: () => settings.setPair(
                  a
                      ? LanguagePair(language.code, pair.b)
                      : LanguagePair(pair.a, language.code),
                ),
              ),
        ],
      );
    }

    Widget side(String code, {required bool a}) => Flexible(
      child: InkWell(
        onTap: () => pick(a: a),
        borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppParams.spacing12.w),
            child: Center(
              widthFactor: 1,
              child: Text(
                l10n.languageName(code),
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLowest,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          side(pair.a, a: true),
          AppCircleIconButton(
            icon: AppIcons.swap,
            semanticLabel: l10n.homeSwapLanguages,
            color: scheme.primary,
            borderColor: Colors.transparent,
            size: 40,
            onPressed: () => settings.setPair(LanguagePair(pair.b, pair.a)),
          ),
          side(pair.b, a: false),
        ],
      ),
    );
  }
}

/// The primary Conversation card.
class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${l10n.homeConversationTitle}. ${l10n.homeConversationBody}',
      excludeSemantics: true,
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          child: Padding(
            padding: EdgeInsets.all(AppParams.spacing24.r),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeConversationTitle,
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                      SizedBox(height: AppParams.spacing8.h),
                      Text(
                        l10n.homeConversationBody,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                      SizedBox(height: AppParams.spacing16.h),
                      Text(
                        l10n.homeConversationOffline,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppParams.spacing12.w),
                Container(
                  width: AppParams.micDefault.r,
                  height: AppParams.micDefault.r,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AppIcon(
                      AppIcons.mic,
                      size: 32,
                      color: scheme.primary,
                    ),
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

/// A secondary mode card (Listen, Meeting).
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.horizontal = false,
  });

  final AppIcons icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = Container(
      width: AppParams.buttonHeight.r,
      height: AppParams.buttonHeight.r,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
      ),
      child: Center(child: AppIcon(icon, color: scheme.onSurface)),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: context.textTheme.titleLarge?.copyWith(
            color: scheme.onSurface,
          ),
        ),
        SizedBox(
          height: horizontal ? AppParams.spacing4.h : AppParams.spacing8.h,
        ),
        Text(
          body,
          style: context.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: '$title. $body',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
          child: Padding(
            padding: EdgeInsets.all(AppParams.spacing20.r),
            child: horizontal
                ? Row(
                    children: [
                      badge,
                      SizedBox(width: AppParams.spacing16.w),
                      Expanded(child: texts),
                      AppIcon(
                        AppIcons.chevronRight,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      badge,
                      SizedBox(height: AppParams.spacing16.h),
                      texts,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// How many of the pair's languages work offline, and the first one to download.
class _OfflineCard extends ConsumerWidget {
  const _OfflineCard({required this.pair});

  final LanguagePair pair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final packs = ref.watch(languagePacksProvider);
    if (packs.loading) {
      return const SizedBox.shrink();
    }
    final langs = [pair.a, pair.b];
    final ready = langs
        .where((l) => packs.pack(l)?.status == PackStatus.ready)
        .length;
    final missing = langs
        .map(packs.pack)
        .whereType<LanguagePack>()
        .where(
          (p) =>
              p.offlineSupported &&
              (p.status == PackStatus.notDownloaded ||
                  p.status == PackStatus.failed),
        )
        .firstOrNull;
    final size = missing == null
        ? null
        : '${((LanguagePack.translationBytes + missing.speechBytes) / (1024 * 1024)).round()} MB';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing16.w,
          vertical: AppParams.spacing12.h,
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.engineOffline, color: scheme.onSurface),
            SizedBox(width: AppParams.spacing12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.homeOfflineReady(ready),
                    style: context.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    missing == null
                        ? l10n.homeOfflineAllReady
                        : l10n.homeOfflineMissing(
                            l10n.languageName(missing.lang),
                            size!,
                          ),
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (missing != null)
              AppPlatformTextButton(
                onPressed: () => context.pushNamed(AppRouteName.languagePacks),
                text: l10n.homeOfflineDownload,
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the most recent session's transcript.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final latest = ref.watch(latestSessionProvider).value;
    if (latest == null) {
      return const SizedBox.shrink();
    }
    final session = latest.session;
    final minutes = (session.durationSec / 60).round();
    final subtitle = [
      minutes < 1 ? l10n.historyUnderAMinute : l10n.historyMinutes(minutes),
      '${l10n.languageName(session.langA)} ⇄ ${l10n.languageName(session.langB)}',
    ].join(' · ');
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        onTap: () => context.pushNamed(
          AppRouteName.transcript,
          pathParameters: {'id': session.id},
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppParams.spacing16.w,
            vertical: AppParams.spacing16.h,
          ),
          child: Row(
            children: [
              AppIcon(AppIcons.navHistory, color: scheme.onSurface),
              SizedBox(width: AppParams.spacing12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeContinue(session.title ?? l10n.historyUntitled),
                      style: context.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

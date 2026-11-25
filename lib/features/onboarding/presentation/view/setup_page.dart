import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_circular_progress_indicator.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_search_field.dart';
import '../../../../common/widgets/app_selectable_chip.dart';
import '../../../../core/engines/selection/capability_matrix.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../navigation/route_const.dart';
import '../../../language_packs/data/model/pack_models.dart';
import '../../../language_packs/data/notifier/language_packs_notifier.dart';
import '../../data/notifier/onboarding_notifier.dart';
import '../../data/state/onboarding_state.dart';

/// Setup S-02: "I speak", "I talk with", then the offline pack offer (F-01).
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Goes one step back, or to Welcome from the first step.
  void _back() {
    _search.clear();
    setState(() => _query = '');
    if (!ref.read(onboardingProvider.notifier).back()) {
      context.goNamed(AppRouteName.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);
    final matrix = ref.watch(capabilityMatrixProvider);
    final loaded = matrix.value;
    if (loaded != null && !loaded.languages.containsKey(state.mine)) {
      Future.microtask(() => notifier.fitTo(loaded));
    }
    final step = state.step.index + 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _back();
        }
      },
      child: AppPlatformScaffold(
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
                      semanticLabel: l10n.setupBack,
                      borderColor: Colors.transparent,
                      onPressed: _back,
                    ),
                    const Spacer(),
                    _ProgressDots(
                      current: step,
                      total: SetupStep.values.length,
                      label: l10n.setupStep(step, SetupStep.values.length),
                    ),
                    const Spacer(),
                    SizedBox(width: AppParams.buttonHeight.r),
                  ],
                ),
              ),
              Expanded(
                child: matrix.when(
                  loading: () => Center(
                    child: AppCircularProgressIndicator(color: scheme.primary),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (matrix) => switch (state.step) {
                    SetupStep.iSpeak => _ISpeak(
                      matrix: matrix,
                      state: state,
                      query: _query,
                      search: _search,
                      onQuery: (q) => setState(() => _query = q),
                    ),
                    SetupStep.talkWith => _TalkWith(
                      matrix: matrix,
                      state: state,
                    ),
                    SetupStep.packs => _Packs(state: state),
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppParams.spacing24.w,
                  AppParams.spacing8.h,
                  AppParams.spacing24.w,
                  AppParams.spacing16.h,
                ),
                child: state.step == SetupStep.packs
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppPlatformElevatedButton(
                            onPressed: () => notifier.finish(download: true),
                            text: l10n.setupPacksDownload,
                          ),
                          SizedBox(height: AppParams.spacing8.h),
                          AppPlatformTextButton(
                            onPressed: () => notifier.finish(download: false),
                            text: l10n.setupPacksLater,
                          ),
                        ],
                      )
                    : AppPlatformElevatedButton(
                        onPressed: state.canContinue
                            ? () {
                                _search.clear();
                                setState(() => _query = '');
                                notifier.next();
                              }
                            : null,
                        text: l10n.setupContinue,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Languages of the matrix, wave 1 first, then by order in the matrix.
List<LanguageCapability> _ordered(CapabilityMatrix matrix) {
  final list = matrix.languages.values.toList();
  final index = {for (var i = 0; i < list.length; i++) list[i].code: i};
  return list..sort((a, b) {
    final wa = a.wave <= 0 ? 99 : a.wave;
    final wb = b.wave <= 0 ? 99 : b.wave;
    return wa != wb ? wa - wb : index[a.code]! - index[b.code]!;
  });
}

/// Step heading and hint.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          hint,
          style: context.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: AppParams.spacing16.h),
      ],
    );
  }
}

/// Step 1: one language, with search (AC-01.2).
class _ISpeak extends ConsumerWidget {
  const _ISpeak({
    required this.matrix,
    required this.state,
    required this.query,
    required this.search,
    required this.onQuery,
  });

  final CapabilityMatrix matrix;
  final OnboardingState state;
  final String query;
  final TextEditingController search;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final q = query.trim().toLowerCase();
    final languages = _ordered(matrix).where((l) {
      if (q.isEmpty) {
        return true;
      }
      return l.name.toLowerCase().contains(q) ||
          l10n.languageName(l.code).toLowerCase().contains(q) ||
          l.code.contains(q);
    }).toList();
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
      children: [
        _Heading(title: l10n.setupISpeakTitle, hint: l10n.setupISpeakHint),
        AppSearchField(
          controller: search,
          hint: l10n.setupSearch,
          clearLabel: l10n.historyClearSearch,
          onChanged: onQuery,
        ),
        SizedBox(height: AppParams.spacing8.h),
        for (final language in languages)
          Semantics(
            selected: language.code == state.mine,
            button: true,
            child: InkWell(
              onTap: () => ref
                  .read(onboardingProvider.notifier)
                  .selectMine(language.code),
              borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: AppParams.buttonHeight.h + AppParams.spacing8.h,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppParams.spacing8.w,
                    vertical: AppParams.spacing8.h,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              language.name,
                              style: context.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                            if (language.name !=
                                l10n.languageName(language.code))
                              Text(
                                l10n.languageName(language.code),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (language.code == state.mine)
                        AppIcon(AppIcons.check, color: scheme.primary),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Step 2: one or more partner languages, with Offline and Live badges (AC-01.3).
class _TalkWith extends ConsumerWidget {
  const _TalkWith({required this.matrix, required this.state});

  final CapabilityMatrix matrix;
  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final languages = _ordered(matrix)
        .where((l) => l.code != state.mine)
        .toList();
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
      children: [
        _Heading(title: l10n.setupTalkWithTitle, hint: l10n.setupTalkWithHint),
        Wrap(
          spacing: AppParams.spacing8.w,
          runSpacing: AppParams.spacing8.h,
          children: [
            for (final language in languages)
              AppSelectableChip(
                label: language.name == l10n.languageName(language.code)
                    ? language.name
                    : '${l10n.languageName(language.code)} · ${language.name}',
                selected: state.partners.contains(language.code),
                onChanged: (_) => ref
                    .read(onboardingProvider.notifier)
                    .togglePartner(language.code),
                badges: [
                  if (language.offlineTranslate && language.asrOnDevice.usable)
                    l10n.badgeOffline,
                  if (language.live) l10n.badgeLive,
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Step 3: download size per language and the Wi-Fi advice (AC-01.4).
class _Packs extends ConsumerWidget {
  const _Packs({required this.state});

  final OnboardingState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final packs = ref.watch(languagePacksProvider);
    var total = 0;
    final rows = <Widget>[];
    for (final lang in state.allLanguages) {
      final pack = packs.pack(lang);
      final offline = pack?.offlineSupported ?? false;
      final bytes = pack == null || !offline || pack.status == PackStatus.ready
          ? 0
          : (pack.translation == ComponentStatus.ready
                    ? 0
                    : LanguagePack.translationBytes) +
                (pack.speech == ComponentStatus.ready ? 0 : pack.speechBytes);
      total += bytes;
      rows.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppParams.spacing8.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.languageName(lang),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                switch (pack?.status) {
                  PackStatus.ready => l10n.packsReady,
                  _ when !offline => l10n.setupPacksNotOffline,
                  _ => _megabytes(bytes),
                },
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
      children: [
        _Heading(title: l10n.setupPacksTitle, hint: l10n.setupPacksHint),
        if (packs.loading)
          Center(child: AppCircularProgressIndicator(color: scheme.primary))
        else ...[
          ...rows,
          Divider(color: scheme.outlineVariant),
          Text(
            l10n.setupPacksTotal(_megabytes(total)),
            style: context.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ],
        SizedBox(height: AppParams.spacing16.h),
        Row(
          children: [
            AppIcon(AppIcons.info, size: 20, color: scheme.onSurfaceVariant),
            SizedBox(width: AppParams.spacing8.w),
            Expanded(
              child: Text(
                l10n.setupPacksWifi,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Formats bytes as whole megabytes.
  static String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).round()} MB';
}

/// Step indicator dots.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.current,
    required this.total,
    required this.label,
  });

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= total; i++)
            Container(
              margin: EdgeInsets.symmetric(horizontal: AppParams.spacing4.w),
              width: (i == current ? 24 : 8).w,
              height: AppParams.engineDot.r,
              decoration: BoxDecoration(
                color: i <= current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
              ),
            ),
        ],
      ),
    );
  }
}

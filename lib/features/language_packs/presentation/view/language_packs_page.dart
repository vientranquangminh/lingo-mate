import '../../../../common/widgets/app_skeleton.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_dialog.dart';
import '../../../../common/widgets/app_platform_switch.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/platform/system_settings.dart';
import '../../data/model/pack_models.dart';
import '../../data/notifier/language_packs_notifier.dart';
import '../widget/pack_row.dart';

/// Offline language packs screen S-16.
class LanguagePacksPage extends ConsumerStatefulWidget {
  const LanguagePacksPage({super.key});

  @override
  ConsumerState<LanguagePacksPage> createState() => _LanguagePacksPageState();
}

class _LanguagePacksPageState extends ConsumerState<LanguagePacksPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(languagePacksProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final state = ref.watch(languagePacksProvider);
    final notifier = ref.read(languagePacksProvider.notifier);
    final matrix = ref.watch(capabilityMatrixProvider).value;
    ref.listen(languagePacksProvider.select((s) => s.askMobileDataFor), (
      _,
      lang,
    ) async {
      if (lang == null) {
        return;
      }
      final useMobileData = await showAppPlatformDialog(
        context: context,
        title: l10n.packsMobileDataTitle,
        body: l10n.packsMobileDataBody,
        confirm: l10n.packsUseMobileData,
        cancel: l10n.packsWaitWifi,
      );
      await notifier.answerMobileData(useMobileData: useMobileData ?? false);
    });

    /// Builds the row of one pack.
    Widget row(LanguagePack pack) {
      final name = l10n.languageName(pack.lang);
      final endonym = matrix?.languages[pack.lang]?.name ?? name;
      return PackRow(
        key: ValueKey(pack.lang),
        pack: pack,
        name: name,
        endonym: endonym,
        isPivot:
            pack.lang == LanguagePacksNotifier.pivot &&
            !notifier.canDelete(pack.lang),
        onDownload: () => notifier.download(pack.lang),
        onInstallVoice: () =>
            ref.read(systemSettingsProvider).installTtsVoice(),
        onDelete: pack.started && notifier.canDelete(pack.lang)
            ? () async {
                final confirmed = await showAppPlatformDialog(
                  context: context,
                  title: l10n.packsDeleteTitle(name),
                  body: l10n.packsDeleteBody(name),
                  confirm: l10n.packsDelete,
                  cancel: l10n.commonCancel,
                  destructive: true,
                );
                if (confirmed ?? false) {
                  await notifier.delete(pack.lang);
                }
              }
            : null,
      );
    }

    final yours = state.packs.where((p) => p.started).toList();
    final others = state.packs.where((p) => !p.started).toList()
      ..sort((a, b) {
        if (a.offlineSupported != b.offlineSupported) {
          return a.offlineSupported ? -1 : 1;
        }
        return 0;
      });
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.packsTitle)),
      body: state.loading
          ? const AppSkeletonList()
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: AppParams.spacing16.w,
                vertical: AppParams.spacing16.h,
              ),
              children: [
                _StorageCard(
                  used: PackRow.megabytes(state.usedBytes),
                  wifiOnly: state.wifiOnly,
                  onWifiOnlyChanged: notifier.setWifiOnly,
                ),
                if (yours.isNotEmpty) ...[
                  _SectionTitle(l10n.packsYourLanguages),
                  ...yours.map(row),
                ],
                if (others.isNotEmpty) ...[
                  _SectionTitle(l10n.packsOtherLanguages),
                  ...others.map(row),
                ],
              ],
            ),
    );
  }
}

/// Storage used by packs and the Wi-Fi-only setting.
class _StorageCard extends StatelessWidget {
  const _StorageCard({
    required this.used,
    required this.wifiOnly,
    required this.onWifiOnlyChanged,
  });

  final String used;
  final bool wifiOnly;
  final ValueChanged<bool> onWifiOnlyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppParams.spacing16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.packsUsed(used),
              style: context.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: AppParams.spacing8.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.packsWifiOnly,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                AppPlatformSwitch(
                  value: wifiOnly,
                  onChanged: onWifiOnlyChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Upper-case heading above a group of packs.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppParams.spacing24.h,
        bottom: AppParams.spacing8.h,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

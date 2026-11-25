import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engines/engines.dart';
import '../../core/engines/selection/engine_selector.dart';
import '../extensions/build_context_ext.dart';
import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// Shows the engines with why each is unavailable; returns the chosen pin, or null when dismissed (AC-05.7).
Future<EngineSheetChoice?> showEngineSheet({
  required BuildContext context,
  required EngineKind? current,
  required EngineKind? pinned,
  required Map<EngineKind, EngineBlock> blocked,
  List<EngineKind> engines = const [EngineKind.standard, EngineKind.offline],
}) {
  final sheet = EngineSheet(
    current: current,
    pinned: pinned,
    blocked: blocked,
    engines: engines,
  );
  if (context.isCupertino) {
    return showCupertinoModalPopup<EngineSheetChoice>(
      context: context,
      builder: (_) => sheet,
    );
  }
  return showModalBottomSheet<EngineSheetChoice>(
    context: context,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppParams.radiusSheet.r),
      ),
    ),
    builder: (_) => sheet,
  );
}

/// The engine picked in the sheet; [engine] null means automatic.
class EngineSheetChoice {
  const EngineSheetChoice(this.engine);

  final EngineKind? engine;
}

/// Lists Automatic and each engine, with the reason it cannot be used.
class EngineSheet extends StatelessWidget {
  const EngineSheet({
    super.key,
    required this.current,
    required this.pinned,
    required this.blocked,
    required this.engines,
  });

  final EngineKind? current;
  final EngineKind? pinned;
  final Map<EngineKind, EngineBlock> blocked;
  final List<EngineKind> engines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppParams.radiusSheet.r),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppParams.spacing16.w,
            AppParams.spacing8.h,
            AppParams.spacing16.w,
            AppParams.spacing16.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.engineSheetTitle,
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: AppParams.spacing12.h),
              _Option(
                icon: AppIcons.autoTurn,
                title: l10n.engineSheetAutomatic,
                subtitle: l10n.engineSheetAutomaticHint,
                selected: pinned == null,
                onTap: () =>
                    Navigator.of(context).pop(const EngineSheetChoice(null)),
              ),
              for (final engine in engines)
                _Option(
                  icon: switch (engine) {
                    EngineKind.offline => AppIcons.engineOffline,
                    EngineKind.standard => AppIcons.engineStandard,
                    EngineKind.live => AppIcons.engineLive,
                  },
                  title: switch (engine) {
                    EngineKind.offline => l10n.engineOffline,
                    EngineKind.standard => l10n.engineStandard,
                    EngineKind.live => l10n.engineLive,
                  },
                  subtitle: switch (blocked[engine]) {
                    null when engine == current => l10n.engineSheetInUse,
                    null => null,
                    final block => blockReason(context, block),
                  },
                  selected: pinned == engine,
                  onTap: blocked.containsKey(engine)
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop(EngineSheetChoice(engine)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the user-facing reason for [block].
  static String blockReason(BuildContext context, EngineBlock block) {
    final l10n = context.localization;
    return switch (block) {
      EngineBlock.notSupported => l10n.engineBlockNotSupported,
      EngineBlock.noInternet => l10n.engineBlockNoInternet,
      EngineBlock.regionBlocked => l10n.engineBlockRegionBlocked,
      EngineBlock.liveDisabled => l10n.engineBlockLiveDisabled,
      EngineBlock.liveQuota => l10n.engineBlockLiveQuota,
      EngineBlock.standardQuota => l10n.engineBlockStandardQuota,
      EngineBlock.standardFailing => l10n.engineBlockStandardFailing,
      EngineBlock.standardDisabled => l10n.engineBlockStandardDisabled,
      EngineBlock.packsMissing => l10n.engineBlockPacksMissing,
    };
  }
}

/// One row of the engine sheet.
class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final AppIcons icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final color = enabled ? scheme.onSurface : scheme.onSurfaceVariant;
    final subtitle = this.subtitle;
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing8.w,
              vertical: AppParams.spacing8.h,
            ),
            child: Row(
              children: [
                AppIcon(icon, color: color),
                SizedBox(width: AppParams.spacing12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: color,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  AppIcon(AppIcons.check, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

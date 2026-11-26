import 'app_motion.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/engines/engines.dart';
import '../extensions/build_context_ext.dart';
import '../resources/app_colors.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// Always-visible chip naming the running engine, with its colour, icon and Live's on-air dot (doc 08 §3, AC-05.1).
class EngineChip extends StatelessWidget {
  const EngineChip({super.key, required this.engine, this.onTap});

  final EngineKind? engine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, chip) = switch (engine) {
      EngineKind.offline => (
        AppIcons.engineOffline,
        l10n.engineOffline,
        colors.engineOffline,
      ),
      EngineKind.standard => (
        AppIcons.engineStandard,
        l10n.engineStandard,
        colors.engineStandard,
      ),
      EngineKind.live => (
        AppIcons.engineLive,
        l10n.engineLive,
        colors.engineLive,
      ),
      null => (
        AppIcons.engineUnavailable,
        l10n.engineUnavailable,
        EngineChipColors(
          foreground: scheme.onSurfaceVariant,
          background: scheme.surfaceContainerHigh,
        ),
      ),
    };
    return Semantics(
      button: onTap != null,
      label: l10n.engineChipSemantics(label),
      excludeSemantics: true,
      child: Material(
        color: chip.background,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: AppParams.buttonHeight.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppParams.spacing12.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon,
                    size: AppParams.engineIcon,
                    color: chip.foreground,
                  ),
                  SizedBox(width: AppParams.spacing4.w),
                  Flexible(
                    child: AppSwitcher(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        label,
                        key: ValueKey(label),
                        style: context.textTheme.labelLarge?.copyWith(
                          color: chip.foreground,
                        ),
                      ),
                    ),
                  ),
                  if (engine == EngineKind.live) ...[
                    SizedBox(width: AppParams.spacing8.w),
                    _OnAirDot(color: chip.dot),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live's pulsing on-air dot; still when the system asks to reduce motion.
class _OnAirDot extends StatefulWidget {
  const _OnAirDot({required this.color});

  final Color color;

  @override
  State<_OnAirDot> createState() => _OnAirDotState();
}

class _OnAirDotState extends State<_OnAirDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppParams.pulseDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: AppParams.engineDot.r,
        height: AppParams.engineDot.r,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_icon.dart';

/// What the mic button shows (doc 08 MicButton).
enum MicButtonState { idle, listening, processing, speaking, disabled }

/// Round microphone button with a pulsing ring while listening and a label under it.
class MicButton extends StatefulWidget {
  const MicButton({
    super.key,
    required this.state,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.size = AppParams.micDefault,
    this.background,
    this.foreground,
    this.labelColor,
  });

  final MicButtonState state;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double size;
  final Color? background;
  final Color? foreground;
  final Color? labelColor;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: AppParams.micPulseDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  /// Runs the ring only while listening and motion is allowed.
  void _syncPulse() {
    final run =
        widget.state == MicButtonState.listening &&
        !MediaQuery.disableAnimationsOf(context);
    if (run && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!run && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled =
        widget.state != MicButtonState.disabled && widget.onPressed != null;
    final background = enabled
        ? widget.background ?? scheme.primary
        : scheme.surfaceContainerHighest;
    final foreground = enabled
        ? widget.foreground ?? scheme.onPrimary
        : scheme.onSurfaceVariant;
    final size = widget.size.r;
    final listening = widget.state == MicButtonState.listening;
    final ringSize = size * 1.45;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: widget.label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: ringSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (listening)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.isAnimating ? _pulse.value : 0.5;
                      return Container(
                        width: size + (ringSize - size) * (0.4 + 0.6 * t),
                        height: size + (ringSize - size) * (0.4 + 0.6 * t),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: background.withValues(
                            alpha: 0.25 * (1 - t) + 0.08,
                          ),
                        ),
                      );
                    },
                  ),
                Material(
                  color: background,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: enabled ? widget.onPressed : null,
                    child: SizedBox.square(
                      dimension: size,
                      child: Center(child: _icon(foreground, size)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppParams.spacing4.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ringSize * 1.4),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: context.textTheme.labelLarge?.copyWith(
                color: widget.labelColor ?? scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the centre of the button for the current state.
  Widget _icon(Color color, double size) {
    final iconSize = widget.size * 0.4;
    return switch (widget.state) {
      MicButtonState.processing => SizedBox.square(
        dimension: size * 0.4,
        child: CircularProgressIndicator(color: color, strokeWidth: 3.r),
      ),
      MicButtonState.speaking => AppIcon(
        AppIcons.micOff,
        size: iconSize,
        color: color,
      ),
      _ => AppIcon(AppIcons.mic, size: iconSize, color: color),
    };
  }
}

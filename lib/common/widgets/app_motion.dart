import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../resources/app_params.dart';

/// Motion helpers that follow the system "remove animations" setting.
abstract final class AppMotion {
  /// Returns [duration], or zero when the user turned animations off.
  static Duration of(BuildContext context, [Duration? duration]) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : duration ?? AppParams.standardDuration;
}

/// Fades and slides its child in once, when it first appears (new captions, lines, list rows).
class AppFadeSlideIn extends StatefulWidget {
  const AppFadeSlideIn({super.key, required this.child, this.delay});

  final Widget child;
  final Duration? delay;

  @override
  State<AppFadeSlideIn> createState() => _AppFadeSlideInState();
}

class _AppFadeSlideInState extends State<AppFadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppParams.enterDuration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    final duration = AppMotion.of(context, AppParams.enterDuration);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller.duration = duration;
    final delay = widget.delay;
    if (delay == null || delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
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
      opacity: _curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, AppParams.enterOffset),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Cross-fades between children and animates the size change, for text that changes in place (translating → translation, draft words).
class AppSwitcher extends StatelessWidget {
  const AppSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.topLeft,
  });

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.of(context);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) =>
            Stack(alignment: alignment, children: [...previous, ?current]),
        child: child,
      ),
    );
  }
}

/// Three dots that rise in turn, shown while the other side is answering; still when animations are off.
class AppTypingDots extends StatefulWidget {
  const AppTypingDots({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<AppTypingDots> createState() => _AppTypingDotsState();
}

class _AppTypingDotsState extends State<AppTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppParams.pulseDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context, AppParams.pulseDuration) == Duration.zero) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size.r;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: size / 4),
              child: Transform.translate(
                offset: Offset(0, -size / 2 * _lift(i)),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.4 + 0.6 * _lift(i)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns how high dot [i] is now, from 0 to 1.
  double _lift(int i) {
    final phase = (_controller.value - i * 0.2) % 1;
    return phase < 0.5
        ? Curves.easeOut.transform(phase * 2)
        : Curves.easeIn.transform(2 - phase * 2);
  }
}

/// Fades and lifts [child] in again whenever [index] changes, for switching tabs without losing their state.
class AppTabFade extends StatefulWidget {
  const AppTabFade({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<AppTabFade> createState() => _AppTabFadeState();
}

class _AppTabFadeState extends State<AppTabFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppParams.enterDuration,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(AppTabFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) {
      return;
    }
    final duration = AppMotion.of(context, AppParams.enterDuration);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: Tween(begin: AppParams.tabFadeScale, end: 1.0).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../resources/app_params.dart';
import 'app_motion.dart';

/// Placeholder rows with a soft shimmer, shown while a list loads instead of a spinner.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.rows = 5, this.padding});

  final int rows;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding:
            padding ??
            EdgeInsets.symmetric(
              horizontal: AppParams.spacing20.w,
              vertical: AppParams.spacing16.h,
            ),
        itemCount: rows,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: AppParams.spacing20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeletonBox(widthFactor: 0.35),
              SizedBox(height: AppParams.spacing8.h),
              AppSkeletonBox(widthFactor: index.isEven ? 0.9 : 0.75),
              SizedBox(height: AppParams.spacing8.h),
              AppSkeletonBox(widthFactor: index.isEven ? 0.6 : 0.8),
            ],
          ),
        ),
      ),
    );
  }
}

/// One rounded placeholder bar, [widthFactor] of the available width.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({super.key, this.widthFactor = 1, this.height});

  final double widthFactor;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: (height ?? AppParams.skeletonLineHeight).h,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppParams.radius4.r),
        ),
      ),
    );
  }
}

/// Sweeps a light band across [child]; still when animations are off.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppParams.shimmerDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.of(context, AppParams.shimmerDuration) == Duration.zero) {
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
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surface;
    return Semantics(
      container: true,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _controller.value * 3 - 1;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect),
            child: child,
          );
        },
      ),
    );
  }
}

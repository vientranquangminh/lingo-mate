import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_colors.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../navigation/route_const.dart';
import '../../../../common/widgets/app_language_button.dart';

/// Welcome screen S-01: what the app does, the privacy promise and the app language (AC-01.1).
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppParams.spacing24.w,
                  vertical: AppParams.spacing16.h,
                ),
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AppLanguageButton(),
                  ),
                  SizedBox(height: AppParams.spacing24.h),
                  const ExcludeSemantics(child: _Illustration()),
                  SizedBox(height: AppParams.spacing32.h),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.welcomeTitle,
                      style: context.textTheme.displaySmall?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(height: AppParams.spacing8.h),
                  Text(
                    l10n.welcomeSubtitle,
                    style: context.textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: AppParams.spacing24.h),
                  _Prop(
                    icon: AppIcons.mic,
                    tint: colors.engineStandard,
                    text: l10n.welcomePropLive,
                  ),
                  _Prop(
                    icon: AppIcons.engineOffline,
                    tint: colors.engineOffline,
                    text: l10n.welcomePropOffline,
                  ),
                  _Prop(
                    icon: AppIcons.bookmark,
                    tint: EngineChipColors(
                      foreground: scheme.onSurface,
                      background: scheme.surfaceContainerHigh,
                    ),
                    text: l10n.welcomePropLearn,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppParams.spacing24.w,
                AppParams.spacing8.h,
                AppParams.spacing24.w,
                AppParams.spacing16.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcon(
                        AppIcons.lock,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      SizedBox(width: AppParams.spacing8.w),
                      Flexible(
                        child: Text(
                          l10n.welcomePrivacy,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppParams.spacing12.h),
                  AppPlatformElevatedButton(
                    onPressed: () => context.goNamed(AppRouteName.setup),
                    text: l10n.welcomeGetStarted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two sample bubbles: the user's sentence on paper, its translation on ink.
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(right: AppParams.spacing48.w),
          child: _Bubble(
            label: l10n.welcomeSampleFromLabel,
            text: l10n.welcomeSampleFrom,
            background: scheme.surfaceContainerLowest,
            foreground: scheme.onSurface,
            border: scheme.outlineVariant,
          ),
        ),
        SizedBox(height: AppParams.spacing12.h),
        Padding(
          padding: EdgeInsets.only(left: AppParams.spacing48.w),
          child: _Bubble(
            label: l10n.welcomeSampleToLabel,
            text: l10n.welcomeSampleTo,
            background: scheme.inverseSurface,
            foreground: scheme.onInverseSurface,
          ),
        ),
      ],
    );
  }
}

/// One rounded speech bubble with a language label.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.label,
    required this.text,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final String text;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppParams.spacing20.r),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: foreground.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: AppParams.spacing4.h),
          Text(
            text,
            style: context.textTheme.titleLarge?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// A value proposition with a tinted icon.
class _Prop extends StatelessWidget {
  const _Prop({required this.icon, required this.tint, required this.text});

  final AppIcons icon;
  final EngineChipColors tint;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppParams.spacing8.h),
      child: Row(
        children: [
          Container(
            width: AppParams.buttonHeight.r,
            height: AppParams.buttonHeight.r,
            decoration: BoxDecoration(
              color: tint.background,
              borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
            ),
            child: Center(child: AppIcon(icon, color: tint.foreground)),
          ),
          SizedBox(width: AppParams.spacing16.w),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

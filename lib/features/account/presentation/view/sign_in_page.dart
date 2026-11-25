import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/account_merge_prompt.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../navigation/route_const.dart';
import '../widget/sign_in_reason_text.dart';

/// S-24 Sign in: why, Continue with Google, Continue with email, Later (F-13, AC-13.2).
class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.reason = SignInReason.account});

  final SignInReason reason;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final benefits = [
      l10n.signInBenefitSync,
      l10n.signInBenefitLive,
      l10n.signInBenefitRestore,
    ];
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: AppParams.spacing24.w),
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppCircleIconButton(
                icon: AppIcons.close,
                semanticLabel: l10n.signInLater,
                borderColor: Colors.transparent,
                onPressed: () => context.pop(false),
              ),
            ),
            SizedBox(height: AppParams.spacing16.h),
            Semantics(
              header: true,
              child: Text(
                l10n.signInTitle,
                style: context.textTheme.headlineMedium?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(height: AppParams.spacing8.h),
            Text(
              SignInReasonText.of(l10n, widget.reason),
              style: context.textTheme.bodyLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            SizedBox(height: AppParams.spacing16.h),
            for (final benefit in benefits)
              Padding(
                padding: EdgeInsets.only(bottom: AppParams.spacing12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(AppIcons.check, color: scheme.primary),
                    SizedBox(width: AppParams.spacing12.w),
                    Expanded(
                      child: Text(
                        benefit,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: AppParams.spacing32.h),
            AppPlatformOutlinedButton(
              onPressed: _busy ? null : _google,
              text: l10n.signInGoogle,
              foregroundColor: scheme.onSurface,
            ),
            SizedBox(height: AppParams.spacing12.h),
            AppPlatformOutlinedButton(
              onPressed: _busy ? null : _email,
              text: l10n.signInEmail,
              foregroundColor: scheme.onSurface,
            ),
            SizedBox(height: AppParams.spacing8.h),
            Center(
              child: AppPlatformTextButton(
                onPressed: () => context.pop(false),
                text: l10n.signInLater,
              ),
            ),
            SizedBox(height: AppParams.spacing16.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  AppIcons.engineOffline,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(width: AppParams.spacing8.w),
                Expanded(
                  child: Text(
                    l10n.signInOfflineNote,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppParams.spacing24.h),
          ],
        ),
      ),
    );
  }

  /// Signs in with Google and closes with true on success (AC-13.3, AC-13.4).
  Future<void> _google() async {
    final l10n = context.localization;
    setState(() => _busy = true);
    final result = await ref.read(authServiceProvider).signInWithGoogle();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (result.succeeded) {
      showAppToast(context, l10n.signInDone);
      await promptAccountMerge(context, ref, result);
      if (mounted) {
        context.pop(true);
      }
    } else if (result.outcome != SignInOutcome.cancelled) {
      showAppToast(context, l10n.signInFailed);
    }
  }

  /// Opens the email link flow and closes with its result.
  Future<void> _email() async {
    final done = await context.pushNamed<bool>(AppRouteName.signInEmail);
    if (done == true && mounted) {
      context.pop(true);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_banner.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_dialog.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/platform/system_settings.dart';
import '../../../me/data/repository/data_eraser.dart';

/// Delete account: what goes, the Google Play note, sign in again, confirm (AC-13.12, AC-13.13).
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  /// Where Google Play manages subscriptions.
  static const playSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  bool _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final items = [
      l10n.deleteAccountItemAccount,
      l10n.deleteAccountItemCloud,
      l10n.deleteAccountItemUsage,
      l10n.deleteAccountItemPhone,
    ];
    final message = _message;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      appBar: AppPlatformAppBar(title: Text(l10n.deleteAccountTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppParams.spacing24.r),
          children: [
            Text(
              l10n.deleteAccountIntro,
              style: context.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: AppParams.spacing12.h),
            for (final item in items)
              Padding(
                padding: EdgeInsets.only(bottom: AppParams.spacing8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIcon(AppIcons.delete, size: 20, color: scheme.error),
                    SizedBox(width: AppParams.spacing12.w),
                    Expanded(
                      child: Text(
                        item,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: AppParams.spacing16.h),
            AppBanner(
              kind: AppBannerKind.warning,
              message: l10n.deleteAccountPlayNote,
              actionLabel: l10n.deleteAccountOpenPlay,
              onAction: () => ref
                  .read(systemSettingsProvider)
                  .openUrl(DeleteAccountPage.playSubscriptionsUrl),
            ),
            if (message != null) ...[
              SizedBox(height: AppParams.spacing16.h),
              AppBanner(kind: AppBannerKind.info, message: message),
            ],
            SizedBox(height: AppParams.spacing24.h),
            AppPlatformElevatedButton(
              onPressed: _busy ? null : _delete,
              loading: _busy,
              color: scheme.error,
              textColor: scheme.onError,
              text: l10n.deleteAccountButton,
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms, signs in again and deletes; on success wipes the phone and restarts onboarding.
  Future<void> _delete() async {
    final l10n = context.localization;
    final auth = ref.read(authServiceProvider);
    final user = auth.currentUser;
    if (user == null) {
      return;
    }
    final confirmed = await showAppPlatformDialog(
      context: context,
      title: l10n.deleteAccountConfirmTitle,
      body: l10n.deleteAccountConfirmBody,
      confirm: l10n.deleteAccountButton,
      cancel: l10n.commonCancel,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    if (user.provider == AuthProviderKind.google) {
      final again = await auth.reauthenticateWithGoogle();
      if (!again.succeeded) {
        _finish(
          again.outcome == SignInOutcome.cancelled
              ? null
              : l10n.deleteAccountFailed,
        );
        return;
      }
    }
    final result = await auth.deleteAccount();
    if (!mounted) {
      return;
    }
    switch (result) {
      case AccountDeletion.deleted:
        await ref.read(dataEraserProvider)(models: false);
        if (mounted) {
          showAppToast(context, l10n.deleteAccountDone);
        }
      case AccountDeletion.needsRecentLogin:
        final email = user.email;
        if (user.provider == AuthProviderKind.email && email != null) {
          await auth.sendEmailLink(email);
          _finish(l10n.deleteAccountEmailAgain(email));
        } else {
          _finish(l10n.deleteAccountFailed);
        }
      case AccountDeletion.failed:
        _finish(l10n.deleteAccountFailed);
    }
  }

  /// Stops the spinner and shows [message].
  void _finish(String? message) {
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }
}

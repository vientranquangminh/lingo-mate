import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_input_dialog.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../common/widgets/settings_row.dart';
import '../../../../common/widgets/user_avatar.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/sessions/session_repository.dart';
import '../widget/provider_label.dart';

/// Account details from the Me account card: name (editable), email, provider and Sign out (S-17, AC-13.11).
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authUserProvider).value;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      appBar: AppPlatformAppBar(title: Text(l10n.accountTitle)),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              children: [
                SizedBox(height: AppParams.spacing24.h),
                Center(child: UserAvatar(user: user, size: 72)),
                SizedBox(height: AppParams.spacing12.h),
                Text(
                  user.displayName ?? user.email ?? '',
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: AppParams.spacing24.h),
                SettingsRow(
                  icon: AppIcons.edit,
                  label: l10n.accountName,
                  value: user.displayName ?? '',
                  onTap: () => _rename(context, ref, user),
                ),
                SettingsRow(
                  icon: AppIcons.email,
                  label: l10n.accountEmail,
                  value: user.email ?? '',
                  onTap: null,
                ),
                SettingsRow(
                  icon: AppIcons.lock,
                  label: l10n.accountProvider,
                  value: ProviderLabel.of(l10n, user.provider),
                  onTap: null,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                SettingsRow(
                  icon: AppIcons.logout,
                  label: l10n.accountSignOut,
                  destructive: true,
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
    );
  }

  /// Asks for a new display name and saves it.
  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final l10n = context.localization;
    final name = await showAppTextInputDialog(
      context: context,
      title: l10n.accountName,
      initialValue: user.displayName ?? '',
      confirm: l10n.commonSave,
      cancel: l10n.commonCancel,
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(authServiceProvider).updateDisplayName(name);
    }
  }

  /// Asks whether to keep this phone's data, signs out and continues anonymously (AC-13.11).
  Future<void> _signOut(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    Future<void> run({required bool remove}) async {
      if (remove) {
        await ref.read(appDatabaseProvider).wipeUserData();
      }
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) {
        showAppToast(context, l10n.accountSignedOut);
        context.pop();
      }
    }

    return showAppActionSheet(
      context: context,
      title: l10n.accountSignOutTitle,
      cancel: l10n.commonCancel,
      actions: [
        AppSheetAction(
          icon: AppIcons.check,
          label: l10n.accountSignOutKeep,
          onSelected: () => run(remove: false),
        ),
        AppSheetAction(
          icon: AppIcons.delete,
          label: l10n.accountSignOutRemove,
          onSelected: () => run(remove: true),
        ),
      ],
    );
  }
}

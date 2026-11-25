import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/require_sign_in.dart';
import '../../../../common/widgets/user_avatar.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../navigation/route_const.dart';

/// The Me account card: initials, name, email and provider, or a sign-in prompt for anonymous users (AC-13.7, AC-13.8).
class AccountCard extends ConsumerWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authUserProvider).value;
    final signedIn = user != null && !user.isAnonymous;
    final provider = switch (user?.provider) {
      AuthProviderKind.google => l10n.accountProviderGoogle,
      AuthProviderKind.email => l10n.accountProviderEmail,
      _ => null,
    };
    final title = signedIn
        ? (user.displayName?.isNotEmpty ?? false)
              ? user.displayName!
              : user.email ?? ''
        : l10n.accountSignInPrompt;
    final subtitle = signedIn
        ? [?user.email, ?provider].join(' · ')
        : l10n.accountSignInPromptBody;
    final radius = BorderRadius.circular(AppParams.radiusCard.r);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerLowest,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => signedIn
              ? context.pushNamed(AppRouteName.account)
              : requireSignIn(context, ref, SignInReason.account),
          child: Container(
            padding: EdgeInsets.all(AppParams.spacing16.r),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                if (signedIn)
                  UserAvatar(user: user)
                else
                  AppIcon(AppIcons.sync, size: 32, color: scheme.primary),
                SizedBox(width: AppParams.spacing16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppIcon(AppIcons.chevronRight, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

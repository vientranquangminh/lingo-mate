import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_text_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_field.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/auth_providers.dart';
import '../widget/email_format.dart';

/// Continue with email: enter an address, get a sign-in link, open it on this phone (AC-13.5).
class EmailSignInPage extends ConsumerStatefulWidget {
  const EmailSignInPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  ConsumerState<EmailSignInPage> createState() => _EmailSignInPageState();
}

class _EmailSignInPageState extends ConsumerState<EmailSignInPage> {
  late final _email = TextEditingController(text: widget.initialEmail);
  String? _sentTo;
  bool _sending = false;
  bool _failed = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Sends the link to the entered address.
  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failed = false;
    });
    final ok = await ref
        .read(authServiceProvider)
        .sendEmailLink(_email.text.trim());
    if (!mounted) {
      return;
    }
    setState(() {
      _sending = false;
      _failed = !ok;
      _sentTo = ok ? _email.text.trim() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    ref.listen<AsyncValue<AppUser?>>(authUserProvider, (_, next) {
      final user = next.value;
      if (user != null && !user.isAnonymous && context.mounted) {
        context.pop(true);
      }
    });
    final sentTo = _sentTo;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      appBar: AppPlatformAppBar(title: Text(l10n.signInEmail)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppParams.spacing24.r),
          children: [
            if (sentTo == null) ...[
              Text(
                l10n.signInEmailIntro,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: AppParams.spacing16.h),
              AppTextField(
                controller: _email,
                label: l10n.signInEmailLabel,
                maxLines: 1,
                onChanged: (_) => setState(() {}),
              ),
              if (_failed) ...[
                SizedBox(height: AppParams.spacing8.h),
                Text(
                  l10n.signInEmailSendFailed,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
              SizedBox(height: AppParams.spacing16.h),
              AppPlatformElevatedButton(
                onPressed: isValidEmail(_email.text) && !_sending
                    ? _send
                    : null,
                loading: _sending,
                text: l10n.signInEmailSend,
              ),
            ] else ...[
              Text(
                l10n.signInEmailSentTitle,
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: AppParams.spacing8.h),
              Text(
                l10n.signInEmailSentBody(sentTo),
                style: context.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: AppParams.spacing16.h),
              AppPlatformElevatedButton(
                onPressed: _sending ? null : _send,
                loading: _sending,
                text: l10n.signInEmailSendAgain,
              ),
              SizedBox(height: AppParams.spacing8.h),
              Center(
                child: AppPlatformTextButton(
                  onPressed: () => setState(() => _sentTo = null),
                  text: l10n.signInEmailChange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

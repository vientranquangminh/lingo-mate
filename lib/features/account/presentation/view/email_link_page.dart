import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_field.dart';
import '../../../../common/widgets/app_toast.dart';
import '../../../../core/auth/auth_models.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../navigation/route_const.dart';
import '../widget/email_format.dart';

/// Finishes an email link that needs the address confirmed (opened on another device) or that failed (AC-13.5).
class EmailLinkPage extends ConsumerStatefulWidget {
  const EmailLinkPage({super.key, required this.link, required this.outcome});

  final String link;
  final EmailLinkOutcome outcome;

  @override
  ConsumerState<EmailLinkPage> createState() => _EmailLinkPageState();
}

class _EmailLinkPageState extends ConsumerState<EmailLinkPage> {
  final _email = TextEditingController();
  late EmailLinkOutcome _outcome = widget.outcome;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  /// Completes the link with the confirmed address.
  Future<void> _confirm() async {
    final l10n = context.localization;
    setState(() => _busy = true);
    final (outcome, _) = await ref
        .read(authServiceProvider)
        .completeEmailLink(widget.link, email: _email.text.trim());
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
    if (outcome == EmailLinkOutcome.signedIn) {
      showAppToast(context, l10n.signInDone);
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final invalid = _outcome == EmailLinkOutcome.invalid;
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      appBar: AppPlatformAppBar(title: Text(l10n.signInEmail)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppParams.spacing24.r),
          children: [
            Text(
              invalid ? l10n.signInLinkInvalid : l10n.signInLinkConfirm,
              style: context.textTheme.bodyLarge?.copyWith(
                color: invalid ? scheme.error : scheme.onSurface,
              ),
            ),
            SizedBox(height: AppParams.spacing16.h),
            if (invalid)
              AppPlatformElevatedButton(
                onPressed: () =>
                    context.pushReplacementNamed(AppRouteName.signInEmail),
                text: l10n.signInEmailSendAgain,
              )
            else ...[
              AppTextField(
                controller: _email,
                label: l10n.signInEmailLabel,
                maxLines: 1,
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: AppParams.spacing16.h),
              AppPlatformElevatedButton(
                onPressed: isValidEmail(_email.text) && !_busy
                    ? _confirm
                    : null,
                loading: _busy,
                text: l10n.signInLinkContinue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

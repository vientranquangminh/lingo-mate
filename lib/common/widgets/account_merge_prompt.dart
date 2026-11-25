import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_models.dart';
import '../../core/phrases/phrase_repository.dart';
import '../../core/sync/sync_controller.dart';
import '../extensions/build_context_ext.dart';
import 'app_platform_dialog.dart';

/// After signing in to an account that already existed, asks whether to merge this phone's phrases into it (AC-13.4).
Future<void> promptAccountMerge(
  BuildContext context,
  WidgetRef ref,
  SignInResult? result,
) async {
  if (result?.outcome != SignInOutcome.switchedAccount) {
    return;
  }
  final count = await ref.read(phraseRepositoryProvider).watchCount().first;
  if (count == 0 || !context.mounted) {
    return;
  }
  final l10n = context.localization;
  final merge = await showAppPlatformDialog(
    context: context,
    title: l10n.syncMergeTitle,
    body: l10n.syncMergeBody(count),
    confirm: l10n.syncMerge,
    cancel: l10n.syncDontMerge,
  );
  await ref.read(accountMergeProvider)(merge: merge ?? true);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/mic_permission.dart';
import '../../core/platform/system_settings.dart';
import '../../core/settings/user_settings.dart';
import '../extensions/build_context_ext.dart';
import 'app_icon.dart';
import 'explainer_sheet.dart';

/// Returns whether the mic may be used, explaining first and asking only now (S-03, AC-01.6); after two refusals offers Settings (AC-01.7).
Future<bool> ensureMicAccess(BuildContext context, WidgetRef ref) async {
  final permission = ref.read(micPermissionProvider);
  final settings = ref.read(userSettingsProvider.notifier);
  final status = await permission.status();
  if (status == MicPermissionStatus.granted) {
    await settings.clearMicDenials();
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final l10n = context.localization;
  if (status == MicPermissionStatus.permanentlyDenied ||
      ref.read(userSettingsProvider).micDenials >= 2) {
    final open = await showExplainerSheet(
      context: context,
      icon: AppIcons.micOff,
      title: l10n.micDeniedTitle,
      body: l10n.micDeniedBody,
      primary: l10n.micDeniedOpenSettings,
      secondary: l10n.micExplainerNotNow,
    );
    if (open) {
      await ref.read(systemSettingsProvider).openAppSettings();
    }
    return false;
  }
  final allow = await showExplainerSheet(
    context: context,
    icon: AppIcons.mic,
    title: l10n.micExplainerTitle,
    body: l10n.micExplainerBody,
    primary: l10n.micExplainerAllow,
    secondary: l10n.micExplainerNotNow,
  );
  if (!allow) {
    return false;
  }
  final result = await permission.request();
  if (result == MicPermissionStatus.granted) {
    await settings.clearMicDenials();
    return true;
  }
  await settings.recordMicDenial();
  return false;
}

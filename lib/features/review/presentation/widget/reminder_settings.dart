import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_time_picker.dart';
import '../../../../common/widgets/settings_row.dart';
import '../../../../common/widgets/settings_toggle_rows.dart';
import '../../../../core/background/background_capture.dart';
import '../../../../core/review/review_reminder.dart';
import '../../../../core/review/review_settings.dart';

/// Shows the reminder settings in a bottom sheet.
Future<void> showReminderSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppParams.radiusSheet.r),
        ),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: AppParams.spacing16.h),
          child: const ReminderSettings(),
        ),
      ),
    );

/// The opt-in daily reminder switch and its time (AC-16.3).
class ReminderSettings extends ConsumerWidget {
  const ReminderSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.localization;
    final settings = ref.watch(reviewSettingsProvider);
    final notifier = ref.read(reviewSettingsProvider.notifier);
    final sync = ref.read(reviewReminderSyncProvider);
    final time = TimeOfDay(
      hour: settings.reminderMinutes ~/ 60,
      minute: settings.reminderMinutes % 60,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSwitchRow(
          label: l10n.reviewReminder,
          description: l10n.reviewReminderDescription,
          value: settings.reminderOn,
          onChanged: (on) async {
            if (on) {
              await ref.read(notificationPermissionProvider)();
            }
            await notifier.setReminderOn(on);
            await sync();
          },
        ),
        if (settings.reminderOn)
          SettingsRow(
            icon: AppIcons.timer,
            label: l10n.reviewReminderTime,
            value: MaterialLocalizations.of(context).formatTimeOfDay(
              time,
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            ),
            onTap: () async {
              final picked = await showAppTimePicker(
                context: context,
                initial: time,
                doneLabel: l10n.commonSave,
              );
              if (picked == null) {
                return;
              }
              await notifier.setReminderMinutes(
                picked.hour * 60 + picked.minute,
              );
              await sync();
            },
          ),
      ],
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/settings/user_settings.dart';

/// Whether the Meeting setup card was dismissed with "Don't show again" (AC-04.1).
final meetingSetupDismissedProvider =
    NotifierProvider<MeetingSetupNotifier, bool>(MeetingSetupNotifier.new);

/// Loads and saves the Meeting setup card choice.
class MeetingSetupNotifier extends Notifier<bool> {
  static const _key = 'meeting_setup_dismissed';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  /// Hides the setup card for good.
  Future<void> dismiss() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

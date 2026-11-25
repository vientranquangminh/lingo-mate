import 'package:intl/intl.dart';

import '../../../../common/widgets/app_icon.dart';
import '../../../../core/engines/engines.dart';
import '../../../../generated/l10n.dart';

/// Labels shared by the history and transcript screens.
abstract final class HistoryFormat {
  /// Returns Today, Yesterday or the full date of [day] in [locale].
  static String dayLabel(
    AppLocalizations l10n,
    String locale,
    DateTime day,
    DateTime now,
  ) {
    final date = DateTime(day.year, day.month, day.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) {
      return l10n.historyToday;
    }
    if (diff == 1) {
      return l10n.historyYesterday;
    }
    return DateFormat.yMMMMEEEEd(locale).format(day);
  }

  /// Returns a duration in whole minutes, or "< 1 min".
  static String duration(AppLocalizations l10n, int seconds) {
    final minutes = (seconds / 60).round();
    return minutes < 1
        ? l10n.historyUnderAMinute
        : l10n.historyMinutes(minutes);
  }

  /// Returns the `VI⇄EN` pair label.
  static String pair(String a, String b) =>
      '${a.toUpperCase()}⇄${b.toUpperCase()}';

  /// Returns the icon of a stored mode.
  static AppIcons modeIcon(String mode) => switch (mode) {
    'listen' => AppIcons.modeListen,
    'meeting' => AppIcons.modeMeeting,
    _ => AppIcons.modeConversation,
  };

  /// Returns the name of a stored mode.
  static String modeName(AppLocalizations l10n, String mode) => switch (mode) {
    'listen' => l10n.modeListen,
    'meeting' => l10n.modeMeeting,
    _ => l10n.modeConversation,
  };

  /// Returns the display name of [engine].
  static String engineName(AppLocalizations l10n, EngineKind engine) =>
      switch (engine) {
        EngineKind.offline => l10n.engineOffline,
        EngineKind.standard => l10n.engineStandard,
        EngineKind.live => l10n.engineLive,
      };
}

import '../../../../common/widgets/app_icon.dart';
import '../../../../generated/l10n.dart';

/// Names and icons of the bundled situations.
abstract final class SituationNames {
  /// Returns the display name of situation [key].
  static String name(AppLocalizations l10n, String key) => switch (key) {
    'airport' => l10n.situationAirport,
    'hotel' => l10n.situationHotel,
    'restaurant' => l10n.situationRestaurant,
    'taxi' => l10n.situationTaxi,
    'shopping' => l10n.situationShopping,
    'health' => l10n.situationHealth,
    'smalltalk' => l10n.situationSmalltalk,
    'meeting' => l10n.situationMeeting,
    _ => key,
  };

  /// Returns the icon whose file name is [fileName].
  static AppIcons icon(String fileName) =>
      AppIcons.values.where((i) => i.fileName == fileName).firstOrNull ??
      AppIcons.navPhrases;
}

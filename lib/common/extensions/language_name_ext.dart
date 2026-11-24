import '../../generated/l10n.dart';

/// Language names in the UI language (doc 08 §6).
extension LanguageNames on AppLocalizations {
  /// Returns the name of the language with BCP-47 [code], or the code itself when unknown.
  String languageName(String code) => switch (code) {
    'en' => languageEn,
    'vi' => languageVi,
    'ja' => languageJa,
    'ko' => languageKo,
    'zh' => languageZh,
    'th' => languageTh,
    'id' => languageId,
    'es' => languageEs,
    'fr' => languageFr,
    'de' => languageDe,
    _ => code.toUpperCase(),
  };
}

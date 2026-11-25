import 'package:flutter/widgets.dart';

import '../common/extensions/language_name_ext.dart';
import '../generated/l10n.dart';

/// The strings one person reads on their half of Conversation and in show mode, in that person's language (F-11, AC-11.8).
class PartnerStrings {
  const PartnerStrings({
    required this.languageName,
    required this.tapToSpeak,
    required this.listening,
    required this.translating,
    required this.speaking,
    required this.micTemplate,
    required this.translationFailed,
    required this.translatedOffline,
    required this.showHint,
  });

  /// Takes the strings from the app's [l10n], naming [lang] in the app language.
  factory PartnerStrings.fromLocalizations(
    AppLocalizations l10n,
    String lang,
  ) => PartnerStrings(
    languageName: l10n.languageName(lang),
    tapToSpeak: l10n.conversationTapToSpeak,
    listening: l10n.conversationListening,
    translating: l10n.conversationTranslating,
    speaking: l10n.conversationSpeaking,
    micTemplate: l10n.conversationMicSemantics(_slot),
    translationFailed: l10n.conversationTranslationFailed,
    translatedOffline: l10n.conversationTranslatedOffline,
    showHint: l10n.showModePartnerHint,
  );

  /// Returns the strings in [lang]: the app's ARB files for UI languages, the bundled wave-1 table otherwise, English as the fallback.
  factory PartnerStrings.forLanguage(String lang) {
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == lang,
    );
    if (supported) {
      return PartnerStrings.fromLocalizations(
        lookupAppLocalizations(Locale(lang)),
        lang,
      );
    }
    return bundled[lang] ??
        PartnerStrings.fromLocalizations(
          lookupAppLocalizations(const Locale('en')),
          lang,
        );
  }

  static const _slot = '{language}';

  final String languageName;
  final String tapToSpeak;
  final String listening;
  final String translating;
  final String speaking;
  final String micTemplate;
  final String translationFailed;
  final String translatedOffline;
  final String showHint;

  /// Returns the microphone's spoken label for [language].
  String micSemantics(String language) =>
      micTemplate.replaceAll(_slot, language);

  /// Wave-1 languages that are not UI languages yet.
  static const bundled = <String, PartnerStrings>{
    'ja': PartnerStrings(
      languageName: '日本語',
      tapToSpeak: 'タップして話す',
      listening: '聞いています…',
      translating: '翻訳中…',
      speaking: '話しています…',
      micTemplate: '{language}のマイク',
      translationFailed: 'この文は翻訳できませんでした。',
      translatedOffline: 'オフラインで翻訳',
      showHint: 'あなたのために翻訳しました',
    ),
    'ko': PartnerStrings(
      languageName: '한국어',
      tapToSpeak: '탭하여 말하기',
      listening: '듣는 중…',
      translating: '번역 중…',
      speaking: '말하는 중…',
      micTemplate: '{language} 마이크',
      translationFailed: '이 문장을 번역하지 못했습니다.',
      translatedOffline: '오프라인으로 번역됨',
      showHint: '당신을 위해 번역했어요',
    ),
    'zh': PartnerStrings(
      languageName: '中文',
      tapToSpeak: '点按说话',
      listening: '正在听…',
      translating: '正在翻译…',
      speaking: '正在朗读…',
      micTemplate: '{language}麦克风',
      translationFailed: '这句话无法翻译。',
      translatedOffline: '离线翻译',
      showHint: '为您翻译',
    ),
    'th': PartnerStrings(
      languageName: 'ไทย',
      tapToSpeak: 'แตะเพื่อพูด',
      listening: 'กำลังฟัง…',
      translating: 'กำลังแปล…',
      speaking: 'กำลังพูด…',
      micTemplate: 'ไมโครโฟนสำหรับ{language}',
      translationFailed: 'แปลประโยคนี้ไม่ได้',
      translatedOffline: 'แปลแบบออฟไลน์',
      showHint: 'แปลให้คุณแล้ว',
    ),
    'id': PartnerStrings(
      languageName: 'Bahasa Indonesia',
      tapToSpeak: 'Ketuk untuk bicara',
      listening: 'Mendengarkan…',
      translating: 'Menerjemahkan…',
      speaking: 'Berbicara…',
      micTemplate: 'Mikrofon untuk {language}',
      translationFailed: 'Kalimat ini tidak dapat diterjemahkan.',
      translatedOffline: 'Diterjemahkan secara offline',
      showHint: 'Diterjemahkan untuk Anda',
    ),
    'es': PartnerStrings(
      languageName: 'Español',
      tapToSpeak: 'Toca para hablar',
      listening: 'Escuchando…',
      translating: 'Traduciendo…',
      speaking: 'Hablando…',
      micTemplate: 'Micrófono para {language}',
      translationFailed: 'No se pudo traducir esta frase.',
      translatedOffline: 'Traducido sin conexión',
      showHint: 'Traducido para ti',
    ),
    'fr': PartnerStrings(
      languageName: 'Français',
      tapToSpeak: 'Touchez pour parler',
      listening: 'Écoute…',
      translating: 'Traduction…',
      speaking: 'Lecture…',
      micTemplate: 'Micro pour {language}',
      translationFailed: 'Impossible de traduire cette phrase.',
      translatedOffline: 'Traduit hors ligne',
      showHint: 'Traduit pour vous',
    ),
    'de': PartnerStrings(
      languageName: 'Deutsch',
      tapToSpeak: 'Zum Sprechen tippen',
      listening: 'Hört zu…',
      translating: 'Wird übersetzt…',
      speaking: 'Spricht…',
      micTemplate: 'Mikrofon für {language}',
      translationFailed: 'Dieser Satz konnte nicht übersetzt werden.',
      translatedOffline: 'Offline übersetzt',
      showHint: 'Für Sie übersetzt',
    ),
  };
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/l10n/partner_strings.dart';

void main() {
  final matrix = jsonDecode(
    File('assets/capability_matrix.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final languages = matrix['languages'] as Map<String, dynamic>;
  final waveOne = [
    for (final entry in languages.entries)
      if ((entry.value as Map<String, dynamic>)['wave'] == 1) entry.key,
  ];
  final english = PartnerStrings.forLanguage('en');

  test('the capability matrix lists the wave-1 languages', () {
    expect(waveOne, containsAll(['en', 'vi', 'ja', 'ko', 'zh', 'th']));
  });

  for (final lang in waveOne.where((l) => l != 'en')) {
    test('$lang has its own partner strings (AC-11.8)', () {
      final strings = PartnerStrings.forLanguage(lang);
      expect(strings.languageName, isNot(english.languageName));
      expect(strings.tapToSpeak, isNot(english.tapToSpeak));
      expect(strings.listening, isNot(english.listening));
      expect(strings.translating, isNot(english.translating));
      expect(strings.speaking, isNot(english.speaking));
      expect(strings.translationFailed, isNot(english.translationFailed));
      expect(strings.translatedOffline, isNot(english.translatedOffline));
      expect(strings.showHint, isNot(english.showHint));
      expect(strings.micTemplate, contains('{language}'));
      expect(
        strings.languageName,
        (languages[lang] as Map<String, dynamic>)['name'],
      );
    });
  }

  test('other languages fall back to English', () {
    final khmer = PartnerStrings.forLanguage('km');
    expect(khmer.tapToSpeak, english.tapToSpeak);
    expect(khmer.showHint, english.showHint);
    expect(khmer.languageName, 'KM');
  });

  test('the microphone label names the language', () {
    expect(english.micSemantics('English'), 'Microphone for English');
  });
}

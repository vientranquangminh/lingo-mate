import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the ARB file at [path] as a JSON map.
Map<String, dynamic> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Returns the message keys of [arb], without metadata entries.
Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Returns the placeholder names used in [message].
Set<String> _placeholders(String message) =>
    RegExp(r'\{(\w+)[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  final template = _readArb('lib/l10n/intl_en.arb');
  final translations = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && !f.path.endsWith('intl_en.arb'))
      .toList();

  test('there is at least one translation besides English', () {
    expect(translations, isNotEmpty);
  });

  for (final file in translations) {
    group(file.uri.pathSegments.last, () {
      final arb = _readArb(file.path);

      test('translates every English message (AC-11.9)', () {
        final missing = _messageKeys(template).difference(_messageKeys(arb));
        expect(missing, isEmpty, reason: 'Missing: ${missing.join(', ')}');
      });

      test('has no message the English template lacks', () {
        final extra = _messageKeys(arb).difference(_messageKeys(template));
        expect(extra, isEmpty, reason: 'Extra: ${extra.join(', ')}');
      });

      test('keeps the placeholders of each message', () {
        for (final key in _messageKeys(
          template,
        ).intersection(_messageKeys(arb))) {
          expect(
            _placeholders(arb[key] as String),
            _placeholders(template[key] as String),
            reason: key,
          );
        }
      });
    });
  }
}

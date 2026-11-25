import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/selection/capability_matrix.dart';
import 'package:lingo_mate/core/quick_phrases/quick_phrases.dart';

/// Serves asset files from the project folder.
class FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(await File(key).readAsBytes()));
}

void main() {
  late QuickPhraseCatalog catalog;

  setUpAll(() async {
    catalog = await QuickPhraseCatalog.load(FileBundle());
  });

  test('8 situations with at least 20 phrases each, in every wave-1 language (AC-09.6)', () {
    final matrix = CapabilityMatrix.fromJson(
      jsonDecode(File(CapabilityMatrix.assetPath).readAsStringSync())
          as Map<String, dynamic>,
    );
    final wave1 = matrix.languages.values
        .where((l) => l.wave == 1)
        .map((l) => l.code)
        .toSet();

    expect(catalog.situations.map((s) => s.key), QuickPhraseCatalog.keys);
    for (final situation in catalog.situations) {
      expect(
        situation.phrases.length,
        greaterThanOrEqualTo(20),
        reason: situation.key,
      );
      for (final phrase in situation.phrases) {
        expect(
          phrase.texts.keys.toSet(),
          containsAll(wave1),
          reason: phrase.key,
        );
        for (final text in phrase.texts.values) {
          expect(text.trim(), isNotEmpty, reason: phrase.key);
        }
      }
    }
    expect(catalog.languages, containsAll(wave1));
  });

  test('phrase keys are unique and every slot appears in each language', () {
    final keys = catalog.situations.expand((s) => s.phrases).map((p) => p.key);
    expect(keys.toSet(), hasLength(keys.length));
    for (final phrase in catalog.situations.expand((s) => s.phrases)) {
      final slot = phrase.slot;
      if (slot == null) {
        for (final text in phrase.texts.values) {
          expect(text, isNot(contains('{')), reason: phrase.key);
        }
        continue;
      }
      expect(slot.values, isNotEmpty);
      for (final text in phrase.texts.values) {
        expect(text, contains('{${slot.name}}'), reason: phrase.key);
      }
    }
  });

  test('a slot value updates the sentence in both languages (AC-09.3)', () {
    final table = catalog.phrase('restaurant.table_for')!;

    expect(table.text('en', value: '3'), 'Do you have a table for 3?');
    expect(table.text('ja', value: '3'), '3人ですが、席はありますか？');
    expect(table.text('en'), 'Do you have a table for 1?');
    expect(
      catalog.phrase('restaurant.bill')!.text('vi'),
      'Tính tiền giúp tôi.',
    );
  });

  test(
    'favourites are kept per language pair, newest first (AC-09.5)',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime(2026);
      final favorites = QuickPhraseFavorites(
        db,
        now: () => now = now.add(const Duration(minutes: 1)),
      );

      await favorites.set('restaurant.bill', 'en', 'ja', true);
      await favorites.set('smalltalk.thank_you', 'en', 'ja', true);
      await favorites.set('restaurant.bill', 'en', 'vi', true);

      expect(await favorites.watch('en', 'ja').first, [
        'smalltalk.thank_you',
        'restaurant.bill',
      ]);
      await favorites.set('restaurant.bill', 'en', 'ja', false);
      expect(await favorites.watch('en', 'ja').first, ['smalltalk.thank_you']);
      expect(await favorites.watch('en', 'vi').first, ['restaurant.bill']);
    },
  );
}

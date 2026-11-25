import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../engines/selection/engine_selector.dart';
import '../sessions/session_repository.dart';
import '../settings/user_settings.dart';

/// A slot in a template phrase, e.g. `{n}` with the choices 1–4 (AC-09.3).
class PhraseSlot extends Equatable {
  const PhraseSlot({required this.name, required this.values});

  final String name;
  final List<String> values;

  @override
  List<Object?> get props => [name, values];
}

/// One bundled quick phrase in every wave-1 language.
class QuickPhrase extends Equatable {
  const QuickPhrase({required this.key, required this.texts, this.slot});

  /// Builds a phrase from the bundle JSON.
  factory QuickPhrase.fromJson(Map<String, dynamic> json) {
    final slot = json['slot'] as Map<String, dynamic>?;
    return QuickPhrase(
      key: json['key'] as String,
      texts: (json['text'] as Map<String, dynamic>).cast<String, String>(),
      slot: slot == null
          ? null
          : PhraseSlot(
              name: slot['name'] as String,
              values: (slot['values'] as List).cast<String>(),
            ),
    );
  }

  final String key;
  final Map<String, String> texts;
  final PhraseSlot? slot;

  /// Whether the phrase exists in [lang].
  bool has(String lang) => texts.containsKey(lang);

  /// Returns the text in [lang] (English when missing) with the slot filled by [value], or its first choice.
  String text(String lang, {String? value}) {
    final raw = texts[lang] ?? texts['en']!;
    final slot = this.slot;
    if (slot == null) {
      return raw;
    }
    return raw.replaceAll('{${slot.name}}', value ?? slot.values.first);
  }

  @override
  List<Object?> get props => [key, texts, slot];
}

/// A situation with its phrases (F-09).
class Situation extends Equatable {
  const Situation({
    required this.key,
    required this.icon,
    required this.phrases,
  });

  /// Builds a situation from the bundle JSON.
  factory Situation.fromJson(Map<String, dynamic> json) => Situation(
    key: json['key'] as String,
    icon: json['icon'] as String,
    phrases: [
      for (final p in json['phrases'] as List)
        QuickPhrase.fromJson(p as Map<String, dynamic>),
    ],
  );

  final String key;
  final String icon;
  final List<QuickPhrase> phrases;

  @override
  List<Object?> get props => [key, icon, phrases];
}

/// The bundled situations, read from `assets/quick_phrases/` so they work offline (AC-09.1).
class QuickPhraseCatalog extends Equatable {
  const QuickPhraseCatalog(this.situations);

  static const keys = [
    'airport',
    'hotel',
    'restaurant',
    'taxi',
    'shopping',
    'health',
    'smalltalk',
    'meeting',
  ];

  final List<Situation> situations;

  /// Loads every situation from [bundle].
  static Future<QuickPhraseCatalog> load(AssetBundle bundle) async =>
      QuickPhraseCatalog([
        for (final key in keys)
          Situation.fromJson(
            jsonDecode(
              await bundle.loadString(
                'assets/quick_phrases/$key.json',
                cache: false,
              ),
            ) as Map<String, dynamic>,
          ),
      ]);

  /// Returns the situation with [key].
  Situation? situation(String key) =>
      situations.where((s) => s.key == key).firstOrNull;

  /// Returns the phrase with [key].
  QuickPhrase? phrase(String key) {
    for (final s in situations) {
      for (final p in s.phrases) {
        if (p.key == key) {
          return p;
        }
      }
    }
    return null;
  }

  /// Languages every phrase is translated into.
  Set<String> get languages {
    final all = situations.expand((s) => s.phrases).toList();
    if (all.isEmpty) {
      return const {};
    }
    return all
        .map((p) => p.texts.keys.toSet())
        .reduce((a, b) => a.intersection(b));
  }

  @override
  List<Object?> get props => [situations];
}

/// The bundled quick phrases.
final quickPhraseCatalogProvider = FutureProvider<QuickPhraseCatalog>(
  (ref) => QuickPhraseCatalog.load(rootBundle),
);

/// The user's own language, shown first on every quick phrase.
final quickSourceProvider = Provider<String>((ref) {
  final settings = ref.watch(userSettingsProvider);
  return settings.myLanguage ?? settings.pair.a;
});

/// The language quick phrases are translated into; the current partner until the user picks another.
final quickTargetProvider = NotifierProvider<QuickTarget, String>(
  QuickTarget.new,
);

/// Holds the "Translate into" choice of the Quick tab.
class QuickTarget extends Notifier<String> {
  @override
  String build() {
    final pair = ref.watch(userSettingsProvider).pair;
    return pair.b != ref.watch(quickSourceProvider) ? pair.b : pair.a;
  }

  /// Translates quick phrases into [lang].
  void select(String lang) => state = lang;
}

/// Starred quick phrase keys for a source → target pair, newest first (AC-09.5).
final quickFavoriteKeysProvider = StreamProvider.autoDispose
    .family<List<String>, LanguagePair>(
      (ref, pair) =>
          ref.watch(quickPhraseFavoritesProvider).watch(pair.a, pair.b),
    );

/// Quick phrase favourites.
final quickPhraseFavoritesProvider = Provider<QuickPhraseFavorites>(
  (ref) => QuickPhraseFavorites(ref.watch(appDatabaseProvider)),
);

/// Starred quick phrases per language pair (AC-09.5), in `quick_phrase_favorites`.
class QuickPhraseFavorites {
  QuickPhraseFavorites(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Returns the stored key of a source → target pair.
  static String pairKey(String from, String to) => '$from-$to';

  /// Phrase keys starred for [from] → [to], newest first.
  Stream<List<String>> watch(String from, String to) =>
      (_db.select(_db.quickPhraseFavorites)
            ..where((f) => f.langPair.equals(pairKey(from, to)))
            ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
          .watch()
          .map((rows) => [for (final r in rows) r.phraseKey]);

  /// Stars or unstars [phraseKey] for [from] → [to].
  Future<void> set(
    String phraseKey,
    String from,
    String to,
    bool starred,
  ) async {
    final pair = pairKey(from, to);
    if (starred) {
      await _db
          .into(_db.quickPhraseFavorites)
          .insertOnConflictUpdate(
            QuickPhraseFavoritesCompanion.insert(
              phraseKey: phraseKey,
              langPair: pair,
              createdAt: _now(),
            ),
          );
    } else {
      await (_db.delete(_db.quickPhraseFavorites)..where(
            (f) => f.phraseKey.equals(phraseKey) & f.langPair.equals(pair),
          ))
          .go();
    }
  }
}

import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'cloud_store.dart';

/// Two-way sync of phrases, tags, review cards and glossaries for one signed-in user; the newest `updatedAt` wins and deletes travel as tombstones (AC-13.9).
class SyncEngine {
  SyncEngine(
    this._db,
    this._store,
    this.uid, {
    required this.lastPush,
    required this.savePush,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final CloudStore _store;
  final String uid;
  final int Function() lastPush;
  final Future<void> Function(int ms) savePush;
  final DateTime Function() _now;
  final Duration debounce;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _pendingCards = <String, CloudDoc>{};
  final _pendingTerms = <String, CloudDoc>{};
  Timer? _timer;
  Future<void> _queue = Future.value();
  final _synced = StreamController<DateTime>.broadcast();

  /// Fires after each push or applied remote change.
  Stream<DateTime> get synced => _synced.stream;

  /// Pushes local changes, then follows the cloud and local edits until [stop].
  Future<void> start() async {
    await push();
    for (final collection in CloudCollection.values) {
      _subscriptions.add(
        _store
            .watch(uid, collection)
            .listen((docs) => _enqueue(() => _apply(collection, docs))),
      );
    }
    _subscriptions.add(
      _db
          .tableUpdates(
            TableUpdateQuery.onAllTables([
              _db.phrases,
              _db.phraseTags,
              _db.srsCards,
              _db.glossarySets,
              _db.glossaryTerms,
            ]),
          )
          .listen((_) => _schedulePush()),
    );
  }

  /// Stops following changes.
  Future<void> stop() async {
    _timer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await _queue;
    await _synced.close();
  }

  /// Runs [task] after the ones before it.
  Future<void> _enqueue(Future<void> Function() task) =>
      _queue = _queue.then((_) => task()).catchError((Object _) {});

  /// Pushes soon after local edits settle.
  void _schedulePush() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(push()));
  }

  /// Uploads every record changed since the last push.
  Future<void> push() => _enqueue(() async {
    final since = lastPush();
    final started = _now().millisecondsSinceEpoch;
    bool changed(DateTime? at) =>
        at == null || at.millisecondsSinceEpoch >= since;
    final phrases = (await _db.select(_db.phrases).get())
        .where((p) => changed(p.updatedAt))
        .toList();
    final tags = await _tagNames([for (final p in phrases) p.id]);
    final cards = (await _db.select(_db.srsCards).get())
        .where((c) => changed(c.updatedAt))
        .toList();
    final sets = (await _db.select(_db.glossarySets).get())
        .where((s) => changed(s.updatedAt))
        .toList();
    final terms = (await _db.select(_db.glossaryTerms).get())
        .where((t) => changed(t.updatedAt))
        .toList();
    await _store.putAll(uid, CloudCollection.phrases, [
      for (final p in phrases)
        CloudDoc(p.id, encodePhrase(p, tags[p.id] ?? const [])),
    ]);
    await _store.putAll(uid, CloudCollection.srs, [
      for (final c in cards) CloudDoc(c.id, encodeCard(c)),
    ]);
    await _store.putAll(uid, CloudCollection.glossarySets, [
      for (final s in sets) CloudDoc(s.id, encodeSet(s)),
    ]);
    await _store.putAll(uid, CloudCollection.glossaryTerms, [
      for (final t in terms) CloudDoc(t.id, encodeTerm(t)),
    ]);
    await savePush(started - 1000);
    _emit();
  });

  /// Applies the cloud copy of [collection] where it is newer than the local row.
  Future<void> _apply(CloudCollection collection, List<CloudDoc> docs) async {
    switch (collection) {
      case CloudCollection.phrases:
        for (final doc in docs) {
          await _applyPhrase(doc);
        }
        await _retryPending();
      case CloudCollection.srs:
        for (final doc in docs) {
          await _applyCard(doc);
        }
      case CloudCollection.glossarySets:
        for (final doc in docs) {
          await _applySet(doc);
        }
        await _retryPending();
      case CloudCollection.glossaryTerms:
        for (final doc in docs) {
          await _applyTerm(doc);
        }
    }
    _emit();
  }

  /// Tells listeners a sync step finished.
  void _emit() {
    if (!_synced.isClosed) {
      _synced.add(_now());
    }
  }

  /// Retries cards and terms that arrived before their phrase or set.
  Future<void> _retryPending() async {
    for (final doc in [..._pendingCards.values]) {
      _pendingCards.remove(doc.id);
      await _applyCard(doc);
    }
    for (final doc in [..._pendingTerms.values]) {
      _pendingTerms.remove(doc.id);
      await _applyTerm(doc);
    }
  }

  /// Whether the cloud value stamped [remote] beats the local [local] stamp.
  static bool _newer(int? remote, DateTime? local) =>
      (remote ?? 0) > (local?.millisecondsSinceEpoch ?? -1);

  /// Applies one phrase, its tags, and drops a local duplicate of it (AC-08.2).
  Future<void> _applyPhrase(CloudDoc doc) async {
    final d = doc.data;
    final local = await (_db.select(
      _db.phrases,
    )..where((p) => p.id.equals(doc.id))).getSingleOrNull();
    final updated = _int(d['updatedAt']);
    if (local != null && !_newer(updated, local.updatedAt)) {
      return;
    }
    final deletedAt = _date(d['deletedAt']);
    await _db.transaction(() async {
      await _db
          .into(_db.phrases)
          .insertOnConflictUpdate(
            PhrasesCompanion.insert(
              id: doc.id,
              sourceLang: d['sourceLang']! as String,
              sourceText: d['sourceText']! as String,
              targetLang: d['targetLang']! as String,
              targetText: d['targetText']! as String,
              note: Value(d['note'] as String?),
              situationKey: Value(d['situationKey'] as String?),
              fromUtteranceId: Value(local?.fromUtteranceId),
              favorite: Value(d['favorite'] == true),
              createdAt: _date(d['createdAt']) ?? _now(),
              updatedAt: _date(updated) ?? _now(),
              deletedAt: Value(deletedAt),
            ),
          );
      await _setTags(doc.id, [
        for (final t in (d['tags'] as List?) ?? const []) '$t',
      ]);
      if (deletedAt == null) {
        await (_db.update(_db.phrases)..where(
              (p) =>
                  p.id.equals(doc.id).not() &
                  p.deletedAt.isNull() &
                  p.sourceLang.equals(d['sourceLang']! as String) &
                  p.targetLang.equals(d['targetLang']! as String) &
                  p.sourceText.equals(d['sourceText']! as String),
            ))
            .write(
              PhrasesCompanion(
                deletedAt: Value(_now()),
                updatedAt: Value(_now()),
              ),
            );
      }
    });
  }

  /// Makes phrase [id] carry exactly the tags in [names].
  Future<void> _setTags(String id, List<String> names) async {
    final wanted = names
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty)
        .toSet();
    final current = await (_db.select(_db.phraseTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.phraseTags.tagId)),
    ])..where(_db.phraseTags.phraseId.equals(id))).get();
    final have = {
      for (final row in current)
        row.readTable(_db.tags).name: row.readTable(_db.tags).id,
    };
    for (final entry in have.entries) {
      if (!wanted.contains(entry.key)) {
        await (_db.delete(_db.phraseTags)..where(
              (pt) => pt.phraseId.equals(id) & pt.tagId.equals(entry.value),
            ))
            .go();
      }
    }
    for (final name in wanted.difference(have.keys.toSet())) {
      final existing = await (_db.select(
        _db.tags,
      )..where((t) => t.name.equals(name))).getSingleOrNull();
      final tagId =
          existing?.id ?? 'tag-${name.hashCode.toRadixString(16)}-${_random()}';
      if (existing == null) {
        await _db
            .into(_db.tags)
            .insert(TagsCompanion.insert(id: tagId, name: name));
      }
      await _db
          .into(_db.phraseTags)
          .insertOnConflictUpdate(
            PhraseTagsCompanion.insert(phraseId: id, tagId: tagId),
          );
    }
  }

  /// Applies one review card once its phrase is here.
  Future<void> _applyCard(CloudDoc doc) async {
    final d = doc.data;
    final phraseId = d['phraseId']! as String;
    final phrase = await (_db.select(
      _db.phrases,
    )..where((p) => p.id.equals(phraseId))).getSingleOrNull();
    if (phrase == null) {
      _pendingCards[doc.id] = doc;
      return;
    }
    final local = await (_db.select(
      _db.srsCards,
    )..where((c) => c.id.equals(doc.id))).getSingleOrNull();
    final updated = _int(d['updatedAt']);
    if (local != null && !_newer(updated, local.updatedAt)) {
      return;
    }
    await _db
        .into(_db.srsCards)
        .insertOnConflictUpdate(
          SrsCardsCompanion.insert(
            id: doc.id,
            phraseId: phraseId,
            direction: d['direction']! as String,
            ease: Value((d['ease']! as num).toDouble()),
            intervalDays: Value(_int(d['intervalDays']) ?? 0),
            reps: Value(_int(d['reps']) ?? 0),
            lapses: Value(_int(d['lapses']) ?? 0),
            dueAt: _date(d['dueAt']) ?? _now(),
            lastReviewedAt: Value(_date(d['lastReviewedAt'])),
            updatedAt: Value(_date(updated)),
          ),
        );
  }

  /// Applies one glossary set; which set is in use stays per device.
  Future<void> _applySet(CloudDoc doc) async {
    final d = doc.data;
    final local = await (_db.select(
      _db.glossarySets,
    )..where((s) => s.id.equals(doc.id))).getSingleOrNull();
    final updated = _int(d['updatedAt']);
    if (local != null && !_newer(updated, local.updatedAt)) {
      return;
    }
    final deletedAt = _date(d['deletedAt']);
    await _db
        .into(_db.glossarySets)
        .insertOnConflictUpdate(
          GlossarySetsCompanion.insert(
            id: doc.id,
            name: d['name']! as String,
            active: Value(deletedAt == null && (local?.active ?? false)),
            createdAt: _date(d['createdAt']) ?? _now(),
            updatedAt: Value(_date(updated)),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  /// Applies one glossary term once its set is here.
  Future<void> _applyTerm(CloudDoc doc) async {
    final d = doc.data;
    final setId = d['setId']! as String;
    final set = await (_db.select(
      _db.glossarySets,
    )..where((s) => s.id.equals(setId))).getSingleOrNull();
    if (set == null) {
      _pendingTerms[doc.id] = doc;
      return;
    }
    final local = await (_db.select(
      _db.glossaryTerms,
    )..where((t) => t.id.equals(doc.id))).getSingleOrNull();
    final updated = _int(d['updatedAt']);
    if (local != null && !_newer(updated, local.updatedAt)) {
      return;
    }
    await _db
        .into(_db.glossaryTerms)
        .insertOnConflictUpdate(
          GlossaryTermsCompanion.insert(
            id: doc.id,
            setId: setId,
            term: d['term']! as String,
            translation: d['translation']! as String,
            note: Value(d['note'] as String?),
            createdAt: _date(d['createdAt']) ?? _now(),
            updatedAt: Value(_date(updated)),
            deletedAt: Value(_date(d['deletedAt'])),
          ),
        );
  }

  /// Tag names of each phrase in [ids].
  Future<Map<String, List<String>>> _tagNames(List<String> ids) async {
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await (_db.select(_db.phraseTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.phraseTags.tagId)),
    ])..where(_db.phraseTags.phraseId.isIn(ids))).get();
    final map = <String, List<String>>{};
    for (final row in rows) {
      map
          .putIfAbsent(row.readTable(_db.phraseTags).phraseId, () => [])
          .add(row.readTable(_db.tags).name);
    }
    return map;
  }

  /// The cloud fields of a phrase; the source utterance stays on the device.
  static Map<String, Object?> encodePhrase(Phrase p, List<String> tags) => {
    'sourceLang': p.sourceLang,
    'sourceText': p.sourceText,
    'targetLang': p.targetLang,
    'targetText': p.targetText,
    'note': p.note,
    'situationKey': p.situationKey,
    'favorite': p.favorite,
    'tags': [...tags]..sort(),
    'createdAt': p.createdAt.millisecondsSinceEpoch,
    'updatedAt': p.updatedAt.millisecondsSinceEpoch,
    'deletedAt': p.deletedAt?.millisecondsSinceEpoch,
  };

  /// The cloud fields of a review card.
  static Map<String, Object?> encodeCard(SrsCard c) => {
    'phraseId': c.phraseId,
    'direction': c.direction,
    'ease': c.ease,
    'intervalDays': c.intervalDays,
    'reps': c.reps,
    'lapses': c.lapses,
    'dueAt': c.dueAt.millisecondsSinceEpoch,
    'lastReviewedAt': c.lastReviewedAt?.millisecondsSinceEpoch,
    'updatedAt': (c.updatedAt ?? c.dueAt).millisecondsSinceEpoch,
  };

  /// The cloud fields of a glossary set.
  static Map<String, Object?> encodeSet(GlossarySet s) => {
    'name': s.name,
    'createdAt': s.createdAt.millisecondsSinceEpoch,
    'updatedAt': (s.updatedAt ?? s.createdAt).millisecondsSinceEpoch,
    'deletedAt': s.deletedAt?.millisecondsSinceEpoch,
  };

  /// The cloud fields of a glossary term.
  static Map<String, Object?> encodeTerm(GlossaryTerm t) => {
    'setId': t.setId,
    'term': t.term,
    'translation': t.translation,
    'note': t.note,
    'createdAt': t.createdAt.millisecondsSinceEpoch,
    'updatedAt': (t.updatedAt ?? t.createdAt).millisecondsSinceEpoch,
    'deletedAt': t.deletedAt?.millisecondsSinceEpoch,
  };

  /// Reads an integer field.
  static int? _int(Object? value) => value is num ? value.toInt() : null;

  /// Reads a millisecond timestamp field.
  static DateTime? _date(Object? value) =>
      value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;

  /// A short random suffix for new tag ids.
  static String _random() =>
      Random().nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
}

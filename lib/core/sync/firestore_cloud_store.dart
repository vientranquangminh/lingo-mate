import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloud_store.dart';

/// [CloudStore] on Cloud Firestore (doc 03 §9.2).
class FirestoreCloudStore implements CloudStore {
  FirestoreCloudStore() : _db = FirebaseFirestore.instance;

  static const _batchSize = 400;

  final FirebaseFirestore _db;

  /// The user's document.
  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<List<CloudDoc>> watch(String uid, CloudCollection collection) =>
      _user(uid)
          .collection(collection.path)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs) CloudDoc(doc.id, doc.data()),
            ],
          );

  @override
  Future<void> putAll(
    String uid,
    CloudCollection collection,
    List<CloudDoc> docs,
  ) async {
    final target = _user(uid).collection(collection.path);
    for (var start = 0; start < docs.length; start += _batchSize) {
      final batch = _db.batch();
      for (final doc in docs.sublist(
        start,
        min(start + _batchSize, docs.length),
      )) {
        batch.set(target.doc(doc.id), doc.data);
      }
      await batch.commit();
    }
  }

  @override
  Future<void> putProfile(String uid, Map<String, Object?> profile) =>
      _db.runTransaction((tx) async {
        final ref = _user(uid);
        final current = (await tx.get(ref)).data() ?? const {};
        final stats = <String, Object?>{
          ...?current['stats'] as Map<String, dynamic>?,
        };
        final incoming = profile['stats'] as Map<String, Object?>? ?? const {};
        for (final MapEntry(:key, :value) in incoming.entries) {
          final old = stats[key];
          stats[key] = old is num && value is num ? max(old, value) : value;
        }
        tx.set(ref, {
          ...profile,
          'stats': stats,
          'lastActiveAt': FieldValue.serverTimestamp(),
          if (!current.containsKey('createdAt'))
            'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
}

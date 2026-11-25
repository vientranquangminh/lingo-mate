import 'dart:async';

import 'package:lingo_mate/core/sync/cloud_store.dart';

/// In-memory [CloudStore] shared by several "devices".
class FakeCloudStore implements CloudStore {
  final _data = <String, Map<String, Map<String, Object?>>>{};
  final _controllers = <String, StreamController<List<CloudDoc>>>{};
  final profiles = <String, Map<String, Object?>>{};
  int writes = 0;

  /// The key of [collection] for [uid].
  String _key(String uid, CloudCollection collection) =>
      '$uid/${collection.path}';

  /// The docs of [collection] for [uid].
  List<CloudDoc> docs(String uid, CloudCollection collection) => [
    for (final e in (_data[_key(uid, collection)] ?? const {}).entries)
      CloudDoc(e.key, e.value),
  ];

  @override
  Stream<List<CloudDoc>> watch(String uid, CloudCollection collection) {
    final key = _key(uid, collection);
    final controller = _controllers.putIfAbsent(
      key,
      () => StreamController<List<CloudDoc>>.broadcast(),
    );
    return Stream.multi((sink) {
      sink.add(docs(uid, collection));
      final sub = controller.stream.listen(sink.add);
      sink.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> putAll(
    String uid,
    CloudCollection collection,
    List<CloudDoc> docs,
  ) async {
    if (docs.isEmpty) {
      return;
    }
    final key = _key(uid, collection);
    final map = _data.putIfAbsent(key, () => {});
    for (final doc in docs) {
      map[doc.id] = Map.of(doc.data);
      writes++;
    }
    _controllers[key]?.add(this.docs(uid, collection));
  }

  @override
  Future<void> putProfile(String uid, Map<String, Object?> profile) async {
    profiles[uid] = {...?profiles[uid], ...profile};
  }
}

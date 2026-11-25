import 'package:equatable/equatable.dart';

/// One synced record: its id and fields.
class CloudDoc extends Equatable {
  const CloudDoc(this.id, this.data);

  final String id;
  final Map<String, Object?> data;

  @override
  List<Object?> get props => [id, data];
}

/// The synced collections under `users/{uid}`.
enum CloudCollection {
  phrases('phrases'),
  srs('srs'),
  glossarySets('glossary'),
  glossaryTerms('glossaryTerms');

  const CloudCollection(this.path);

  final String path;
}

/// The user's cloud copy behind an interface, so sync runs against Firestore or a fake.
abstract interface class CloudStore {
  /// Emits every record of [collection] for [uid] whenever any of them changes.
  Stream<List<CloudDoc>> watch(String uid, CloudCollection collection);

  /// Writes the records in [docs] to [collection] for [uid].
  Future<void> putAll(
    String uid,
    CloudCollection collection,
    List<CloudDoc> docs,
  );

  /// Merges [profile] into `users/{uid}`; stats keep the larger value.
  Future<void> putProfile(String uid, Map<String, Object?> profile);
}

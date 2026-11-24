import 'package:drift/drift.dart';

/// A translation session in one of the modes.
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  TextColumn get engineInitial => text()();
  TextColumn get langA => text()();
  TextColumn get langB => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get liveSec => integer().withDefault(const Constant(0))();
  IntColumn get standardSec => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One recognised and translated utterance of a session.
@TableIndex(name: 'utterances_session_start', columns: {#sessionId, #startMs})
class Utterances extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get speaker => text().nullable()();
  TextColumn get sourceLang => text()();
  TextColumn get sourceText => text()();
  TextColumn get targetLang => text()();
  TextColumn get targetText => text()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get engine => text()();
  IntColumn get latencyMs => integer().nullable()();
  BoolColumn get isSaved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A phrase saved to the phrasebook.
@TableIndex(name: 'phrases_langs', columns: {#sourceLang, #targetLang})
class Phrases extends Table {
  TextColumn get id => text()();
  TextColumn get sourceLang => text()();
  TextColumn get sourceText => text()();
  TextColumn get targetLang => text()();
  TextColumn get targetText => text()();
  TextColumn get note => text().nullable()();
  TextColumn get situationKey => text().nullable()();
  TextColumn get fromUtteranceId => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A user-defined phrasebook tag.
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Links phrases to tags.
class PhraseTags extends Table {
  TextColumn get phraseId =>
      text().references(Phrases, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => {phraseId, tagId};
}

/// A quick phrase the user starred for a language pair.
class QuickPhraseFavorites extends Table {
  TextColumn get phraseKey => text()();
  TextColumn get langPair => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {phraseKey, langPair};
}

/// Download state of the offline models for one language.
class LanguagePacks extends Table {
  TextColumn get lang => text()();
  TextColumn get asrModelId => text().nullable()();
  IntColumn get asrBytes => integer().withDefault(const Constant(0))();
  BoolColumn get mlkitDownloaded =>
      boolean().withDefault(const Constant(false))();
  TextColumn get status => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {lang};
}

/// Seconds of metered engine use, kept for quota checks and sync.
class UsageLedger extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get engine => text()();
  IntColumn get seconds => integer()();
  DateTimeColumn get at => dateTime()();
  TextColumn get sessionId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

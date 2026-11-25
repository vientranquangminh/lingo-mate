import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late DateTime now;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 11, 24, 14, 2);
    repo = SessionRepository(db, now: () => now);
  });

  tearDown(() => db.close());

  /// Returns an utterance from [startMs] lasting [ms].
  NewUtterance line(
    String source,
    String target, {
    int startMs = 0,
    int ms = 2000,
    UtteranceEngine engine = UtteranceEngine.standard,
    String speaker = 'a',
  }) => NewUtterance(
    speaker: speaker,
    sourceLang: 'vi',
    sourceText: source,
    targetLang: 'en',
    targetText: target,
    startMs: startMs,
    endMs: startMs + ms,
    engine: engine,
  );

  /// Starts a Conversation session in vi ⇄ en.
  Future<String> start() => repo.start(
    mode: SessionMode.conversation,
    engine: EngineKind.standard,
    pair: const LanguagePair('vi', 'en'),
  );

  test('finish sets duration, metered seconds and the auto title', () async {
    final id = await start();
    await repo.addUtterance(
      id,
      line('Xin chào. Bạn khỏe không?', 'Hello. How are you?', ms: 3000),
    );
    await repo.addUtterance(
      id,
      line(
        'Mạng chập chờn',
        'The connection is unstable',
        startMs: 5000,
        engine: UtteranceEngine.offlineFallback,
      ),
    );
    now = now.add(const Duration(minutes: 38));

    await repo.finish(id);

    final detail = (await repo.load(id))!;
    expect(detail.session.durationSec, 38 * 60);
    expect(detail.session.standardSec, 3);
    expect(detail.session.liveSec, 0);
    expect(detail.session.title, 'Hello.');
    expect(detail.session.endedAt, now);
    expect(detail.engineSeconds, {
      EngineKind.standard: 3,
      EngineKind.offline: 2,
    });
    expect(detail.mainEngine, EngineKind.standard);
  });

  test('a long first line is shortened for the title', () async {
    final id = await start();
    await repo.addUtterance(id, line('x', 'word ' * 30));

    await repo.finish(id);

    final title = (await repo.load(id))!.session.title!;
    expect(title.length, lessThanOrEqualTo(SessionRepository.titleLength));
    expect(title, endsWith('…'));
  });

  test('a session without utterances is not kept', () async {
    final id = await start();

    await repo.finish(id);

    expect(await repo.load(id), isNull);
  });

  test('history lists finished sessions newest first with the first line (AC-07.1)', () async {
    final older = await start();
    await repo.addUtterance(older, line('Một', '', startMs: 0));
    await repo.addUtterance(older, line('Hai', 'Two', startMs: 1000));
    await repo.finish(older);
    now = now.add(const Duration(days: 1));
    final newer = await start();
    await repo.addUtterance(newer, line('Ba', 'Three'));
    await repo.finish(newer);
    await start();

    final sessions = await repo.watchSessions().first;

    expect(sessions.map((s) => s.session.id), [newer, older]);
    expect(sessions.map((s) => s.firstLine), ['Three', 'Two']);
  });

  test(
    'search matches word prefixes in either language, ignoring accents',
    () async {
      final id = await start();
      await repo.addUtterance(
        id,
        line('Hoàn tiền trong 24 giờ', 'Refunds within 24 hours'),
      );
      await repo.addUtterance(
        id,
        line('Bạn khỏe không', 'How are you', startMs: 3000),
      );
      await repo.finish(id);

      expect(
        (await repo.search('hoan tien')).single.utterance.targetText,
        'Refunds within 24 hours',
      );
      expect((await repo.search('REFUND')).single.session.id, id);
      expect(await repo.search('khoe'), hasLength(1));
      expect(await repo.search('x'), isEmpty);
      expect(await repo.search('"; DROP'), isEmpty);
    },
  );

  test(
    'search answers within 300 ms over 10,000 utterances (AC-07.3)',
    () async {
      for (var s = 0; s < 20; s++) {
        final id = await start();
        await db.batch((b) {
          for (var i = 0; i < 500; i++) {
            b.insert(
              db.utterances,
              UtterancesCompanion.insert(
                id: '$s-$i',
                sessionId: id,
                sourceLang: 'vi',
                sourceText: 'Câu số $i của phiên $s về thanh toán',
                targetLang: 'en',
                targetText: 'Sentence $i of session $s about payments',
                startMs: i * 1000,
                endMs: i * 1000 + 900,
                engine: 'standard',
              ),
            );
          }
        });
      }

      final watch = Stopwatch()..start();
      final hits = await repo.search('payment');
      watch.stop();

      expect(hits, hasLength(50));
      expect(watch.elapsedMilliseconds, lessThan(300));
    },
  );

  test('delete removes the session and its utterances (AC-07.4)', () async {
    final id = await start();
    await repo.addUtterance(id, line('Xin chào', 'Hello'));
    await repo.finish(id);

    await repo.delete(id);

    expect(await repo.load(id), isNull);
    expect(await db.select(db.utterances).get(), isEmpty);
    expect(await repo.search('hello'), isEmpty);
  });

  test('rename sets and clears the title', () async {
    final id = await start();
    await repo.addUtterance(id, line('Xin chào', 'Hello'));
    await repo.finish(id);

    await repo.rename(id, '  Client meeting ');
    expect((await repo.load(id))!.session.title, 'Client meeting');

    await repo.rename(id, '');
    expect((await repo.load(id))!.session.title, isNull);
  });

  test(
    'plain text lists original then translation per line (AC-07.5)',
    () async {
      final id = await start();
      await repo.addUtterance(id, line('Xin chào', 'Hello'));
      await repo.addUtterance(id, line('Tạm biệt', '', startMs: 3000));
      await repo.finish(id);

      final text = SessionRepository.plainText((await repo.load(id))!);

      expect(text, 'Hello\n\nXin chào\nHello\n\nTạm biệt');
    },
  );

  test('engine values round-trip, with the fallback marked', () {
    expect(
      UtteranceEngine.of(EngineKind.offline, fallback: true).value,
      'offline_fallback',
    );
    expect(UtteranceEngine.parse('offline_fallback').kind, EngineKind.offline);
    expect(UtteranceEngine.parse('???'), UtteranceEngine.none);
  });

  test('upgrading from schema 1 indexes existing utterances', () async {
    final dir = Directory.systemTemp.createTempSync('db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    final v1 = AppDatabase(NativeDatabase(file));
    final id = await SessionRepository(v1).start(
      mode: SessionMode.conversation,
      engine: EngineKind.standard,
      pair: const LanguagePair('vi', 'en'),
    );
    await SessionRepository(v1).addUtterance(id, line('Xin chào', 'Hello'));
    for (final name in [
      'utterances_fts_insert',
      'utterances_fts_delete',
      'utterances_fts_update',
    ]) {
      await v1.customStatement('DROP TRIGGER $name');
    }
    await v1.customStatement('DROP TABLE utterances_fts');
    await v1.customStatement('DROP TABLE srs_cards');
    await v1.customStatement('PRAGMA user_version = 1');
    await v1.close();

    final v2 = AppDatabase(NativeDatabase(file));
    addTearDown(v2.close);

    expect(await SessionRepository(v2).search('hello'), hasLength(1));
  });
}

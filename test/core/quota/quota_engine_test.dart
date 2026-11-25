import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/quota/quota_engine.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';

void main() {
  const limits = QuotaLimits(win5hSec: 1800, weekSec: 3600);
  final t0 = DateTime(2026, 11, 25, 9);

  MeteredUse use(Duration after, int seconds) =>
      (at: t0.add(after), seconds: seconds);

  test(
    'the 5-hour window starts at first use and resets 5 h later (AC-14.1)',
    () {
      final status = QuotaEngine.compute(
        [use(Duration.zero, 600), use(const Duration(hours: 2), 300)],
        limits,
        now: t0.add(const Duration(hours: 3)),
      );

      expect(status.window.usedSec, 900);
      expect(status.window.resetAt, t0.add(const Duration(hours: 5)));
      expect(status.week.resetAt, t0.add(const Duration(days: 7)));
      expect(status.remainingSec, 900);
    },
  );

  test(
    'a use after the window ended opens a new one; the week keeps counting',
    () {
      final status = QuotaEngine.compute(
        [use(Duration.zero, 1700), use(const Duration(hours: 6), 200)],
        limits,
        now: t0.add(const Duration(hours: 6, minutes: 1)),
      );

      expect(status.window.usedSec, 200);
      expect(status.window.start, t0.add(const Duration(hours: 6)));
      expect(status.week.usedSec, 1900);
      expect(status.remainingSec, 1600);
    },
  );

  test('with no use for 5 hours the window is idle', () {
    final status = QuotaEngine.compute(
      [use(Duration.zero, 100)],
      limits,
      now: t0.add(const Duration(hours: 5)),
    );

    expect(status.window.start, isNull);
    expect(status.window.usedSec, 0);
    expect(status.week.usedSec, 100);
  });

  test('exhausted when either window runs out; reset is the earliest exhausted one', () {
    final status = QuotaEngine.compute(
      [use(Duration.zero, 1800)],
      limits,
      now: t0.add(const Duration(minutes: 40)),
    );

    expect(status.exhausted, isTrue);
    expect(status.fraction, 1);
    expect(status.resetAt, t0.add(const Duration(hours: 5)));
  });

  test(
    'limits come from quota_limits, with defaults for missing values (AC-14.8)',
    () {
      expect(
        QuotaLimits.from({
          'free': {
            'standard': {'win5hSec': 600, 'weekSec': 1200},
          },
        }),
        const QuotaLimits(win5hSec: 600, weekSec: 1200),
      );
      expect(QuotaLimits.from(const {}), limits);
    },
  );

  test('Standard and Live lines are metered, Offline lines are not', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = SessionRepository(db, now: () => t0);
    final id = await repo.start(
      mode: SessionMode.conversation,
      engine: EngineKind.standard,
      pair: const LanguagePair('vi', 'en'),
    );
    for (final (engine, ms) in [
      (UtteranceEngine.standard, 2300),
      (UtteranceEngine.offline, 4000),
      (UtteranceEngine.offlineFallback, 4000),
      (UtteranceEngine.live, 900),
    ]) {
      await repo.addUtterance(
        id,
        NewUtterance(
          speaker: 'a',
          sourceLang: 'vi',
          sourceText: 'x',
          targetLang: 'en',
          targetText: 'y',
          startMs: 0,
          endMs: ms,
          engine: engine,
        ),
      );
    }

    final rows = await db.select(db.usageLedger).get();
    expect(
      [for (final r in rows) (r.engine, r.seconds)],
      [('standard', 3), ('live', 1)],
    );
  });
}

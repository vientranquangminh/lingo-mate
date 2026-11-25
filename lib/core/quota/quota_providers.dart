import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/engines.dart';
import '../engines/selection/engine_providers.dart';
import '../review/review_reminder.dart';
import '../sessions/session_repository.dart';
import 'quota_engine.dart';

/// The Standard allowance of the current plan from Remote Config `quota_limits`; the plan is Free until purchases arrive (T-2.6).
final standardLimitsProvider = Provider<QuotaLimits>(
  (ref) => QuotaLimits.from(ref.watch(engineRemoteConfigProvider).quotaLimits),
);

/// Where the user stands against the Standard windows, refreshed on new usage and every 30 s (AC-14.1, AC-14.8).
final standardQuotaProvider = StreamProvider<QuotaStatus>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final limits = ref.watch(standardLimitsProvider);
  final clock = ref.watch(reviewClockProvider);
  final controller = StreamController<QuotaStatus>();
  var uses = <MeteredUse>[];
  void emit() =>
      controller.add(QuotaEngine.compute(uses, limits, now: clock()));
  final since = clock().subtract(QuotaEngine.weekLength * 2);
  final query = db.select(db.usageLedger)
    ..where(
      (u) =>
          u.engine.equals(EngineKind.standard.name) &
          u.at.isBiggerOrEqualValue(since),
    );
  final sub = query.watch().listen((rows) {
    uses = [for (final r in rows) (at: r.at, seconds: r.seconds)];
    emit();
  });
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => emit());
  ref.onDispose(() {
    unawaited(sub.cancel());
    timer.cancel();
    unawaited(controller.close());
  });
  return controller.stream;
});

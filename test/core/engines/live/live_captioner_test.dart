import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/live/live_access.dart';
import 'package:lingo_mate/core/engines/live/live_captioner.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';

import 'live_fakes.dart';

void main() {
  LiveGrant grant(String token, {String? id, int block = 600}) =>
      LiveGrant.allowed(
        credentials: LiveEphemeralToken(token),
        blockSec: block,
        tokenId: id,
      );

  test('the issueLiveToken answer is read into a grant (doc 03 §10)', () {
    final ok = CallableLiveAccess.parse({
      'allowed': true,
      'tokens': ['auth_tokens/abc'],
      'tokenId': 't1',
      'blockSec': 300,
      'expiresAt': 1764064800000,
    });
    expect(ok.allowed, isTrue);
    expect(ok.credentials, const LiveEphemeralToken('auth_tokens/abc'));
    expect(ok.blockSec, 300);
    expect(ok.tokenId, 't1');

    final quota = CallableLiveAccess.parse({
      'allowed': false,
      'reason': 'quota',
      'resetAt': '2026-11-25T14:00:00Z',
    });
    expect(quota.denial, LiveDenial.quota);
    expect(quota.resetAt, DateTime.parse('2026-11-25T14:00:00Z'));

    expect(
      CallableLiveAccess.parse({'allowed': false, 'reason': 'sign_in_required'})
          .denial,
      LiveDenial.signInRequired,
    );
  });

  test('transcripts become one caption per turn (F-05)', () {
    fakeAsync((async) {
      final access = FakeLiveAccess()..grants.add(grant('t'));
      final sessions = <FakeLiveSession>[];
      final captioner = LiveCaptioner(
        access: access,
        openSession: (c) => FakeLiveSession(c)..let(sessions.add),
        model: 'm',
        target: 'vi',
        mode: SessionMode.listen,
      );
      final updates = <LiveCaptionEvent>[];
      captioner.events.listen(updates.add);
      bool? started;
      captioner.start().then((v) => started = v);
      async.flushMicrotasks();
      expect(started, isTrue);
      expect(sessions.single.config.targetLanguage, 'vi');

      sessions.single
        ..emit(const LiveInputTranscript('Good '))
        ..emit(const LiveInputTranscript('morning'))
        ..emit(const LiveOutputTranscript('Chào buổi sáng'))
        ..emit(const LiveTurnComplete())
        ..emit(const LiveInputTranscript('Next'));
      async.flushMicrotasks();

      final done = updates.whereType<LiveCaptionUpdate>().where((u) => u.done);
      expect(done.single.original, 'Good morning');
      expect(done.single.translation, 'Chào buổi sáng');
      expect(done.single.turn, 0);
      expect((updates.last as LiveCaptionUpdate).turn, 1);
      captioner.stop();
      async.flushMicrotasks();
    });
  });

  test('a refused grant reports why (AC-14.2)', () async {
    final access = FakeLiveAccess()
      ..grants.add(const LiveGrant.denied(LiveDenial.quota));
    final captioner = LiveCaptioner(
      access: access,
      openSession: FakeLiveSession.new,
      model: 'm',
      target: 'vi',
      mode: SessionMode.listen,
    );

    expect(await captioner.start(), isFalse);
    expect(captioner.denial, LiveDenial.quota);
    await captioner.stop();
  });

  test('the block is renewed before it ends and the used time is reported (AC-14.3, AC-14.4)', () {
    fakeAsync((async) {
      var now = DateTime(2026, 11, 25, 9);
      final access = FakeLiveAccess()
        ..grants.addAll([
          grant('a', id: 'id-a', block: 60),
          grant('b', id: 'id-b'),
        ]);
      final sessions = <FakeLiveSession>[];
      final captioner = LiveCaptioner(
        access: access,
        openSession: (c) => FakeLiveSession(c)..let(sessions.add),
        model: 'm',
        target: 'vi',
        mode: SessionMode.meeting,
        now: () => now,
      );
      unawaited(captioner.start());
      async.flushMicrotasks();

      now = now.add(const Duration(seconds: 55));
      async.elapse(const Duration(seconds: 55, milliseconds: 10));

      expect(sessions, hasLength(2));
      expect(sessions.first.closed, isTrue);
      expect(sessions.last.config.credentials, const LiveEphemeralToken('b'));
      expect(access.reports, [('id-a', 55)]);

      now = now.add(const Duration(seconds: 10));
      unawaited(captioner.stop());
      async.elapse(const Duration(milliseconds: 10));
      expect(access.reports.last, ('id-b', 10));
    });
  });

  test('a closed connection stops Live so the caller can fall back', () {
    fakeAsync((async) {
      final access = FakeLiveAccess()..grants.add(grant('t'));
      final sessions = <FakeLiveSession>[];
      final captioner = LiveCaptioner(
        access: access,
        openSession: (c) => FakeLiveSession(c)..let(sessions.add),
        model: 'm',
        target: 'vi',
        mode: SessionMode.listen,
      );
      final events = <LiveCaptionEvent>[];
      captioner.events.listen(events.add);
      captioner.start();
      async.flushMicrotasks();

      sessions.single.emit(const LiveError('boom'));
      async.flushMicrotasks();

      expect(events.whereType<LiveCaptionStopped>(), hasLength(1));
      captioner.stop();
      async.flushMicrotasks();
    });
  });
}

extension<T> on T {
  /// Calls [f] with this and returns it.
  T let(void Function(T) f) {
    f(this);
    return this;
  }
}

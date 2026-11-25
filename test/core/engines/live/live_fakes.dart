import 'dart:async';
import 'dart:typed_data';

import 'package:lingo_mate/core/engines/live/live_access.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/live/live_session.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';

/// A Live session the test drives by hand.
class FakeLiveSession implements LiveSession {
  FakeLiveSession(this.config);

  final LiveSessionConfig config;
  final _events = StreamController<LiveEvent>.broadcast();
  final sent = <Uint8List>[];
  bool failOpen = false;
  bool closed = false;

  @override
  Stream<LiveEvent> get events => _events.stream;

  @override
  bool get isReady => !closed;

  @override
  Future<void> open() async {
    if (failOpen) {
      throw StateError('setup failed');
    }
  }

  @override
  void sendAudio(Uint8List pcm16k) => sent.add(pcm16k);

  @override
  Future<void> close() async {
    closed = true;
    unawaited(_events.close());
  }

  /// Sends a server event.
  void emit(LiveEvent event) => _events.add(event);
}

/// Hands out scripted grants and records reports.
class FakeLiveAccess implements LiveAccess {
  final grants = <LiveGrant>[];
  final reports = <(String, int)>[];
  int requests = 0;

  @override
  Future<LiveGrant> request({
    required String target,
    required SessionMode mode,
  }) async {
    requests++;
    return grants.isEmpty
        ? const LiveGrant.denied(LiveDenial.unavailable)
        : grants.removeAt(0);
  }

  @override
  Future<void> report(String tokenId, int usedSec) async =>
      reports.add((tokenId, usedSec));
}

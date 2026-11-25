import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../selection/engine_selector.dart';
import 'live_access.dart';
import 'live_models.dart';
import 'live_session.dart';

/// Something the Live captioner reports.
sealed class LiveCaptionEvent extends Equatable {
  const LiveCaptionEvent();
}

/// The caption of the current turn: what was said and its translation so far; [done] when the turn ended.
class LiveCaptionUpdate extends LiveCaptionEvent {
  const LiveCaptionUpdate({
    required this.turn,
    required this.original,
    required this.translation,
    required this.done,
  });

  final int turn;
  final String original;
  final String translation;
  final bool done;

  @override
  List<Object?> get props => [turn, original, translation, done];
}

/// Live stopped and the caller should fall back to Standard; [denial] says why when Live was refused.
class LiveCaptionStopped extends LiveCaptionEvent {
  const LiveCaptionStopped({this.denial, this.resetAt});

  final LiveDenial? denial;
  final DateTime? resetAt;

  @override
  List<Object?> get props => [denial, resetAt];
}

/// Captions from one Live Translate session: asks for a block, renews it before it runs out, and turns transcripts into one caption per turn (F-05, doc 03 §6.3).
class LiveCaptioner {
  LiveCaptioner({
    required this.access,
    required this.openSession,
    required this.model,
    required this.target,
    required this.mode,
    DateTime Function()? now,
    this.renewAhead = const Duration(seconds: 5),
  }) : _now = now ?? DateTime.now;

  final LiveAccess access;
  final LiveSession Function(LiveSessionConfig) openSession;
  final String model;
  final String target;
  final SessionMode mode;
  final DateTime Function() _now;
  final Duration renewAhead;

  final _events = StreamController<LiveCaptionEvent>.broadcast();
  LiveSession? _session;
  StreamSubscription<LiveEvent>? _subscription;
  LiveGrant? _grant;
  DateTime? _openedAt;
  Timer? _renewal;
  bool _stopped = false;
  int _turn = 0;
  final _original = StringBuffer();
  final _translation = StringBuffer();

  /// Why Live was refused at [start], if it was.
  LiveDenial? denial;

  /// Caption updates and the stop notice.
  Stream<LiveCaptionEvent> get events => _events.stream;

  /// Gets a block and opens the session; returns false, with [denial] set, when Live is refused or fails.
  Future<bool> start() async {
    final grant = await access.request(target: target, mode: mode);
    if (!grant.allowed) {
      denial = grant.denial;
      return false;
    }
    try {
      await _open(grant);
      return true;
    } catch (_) {
      await _closeSession();
      denial = LiveDenial.unavailable;
      return false;
    }
  }

  /// Sends one 100 ms chunk of 16 kHz mono PCM16.
  void send(Uint8List chunk) => _session?.sendAudio(chunk);

  /// Closes the session and reports the time used.
  Future<void> stop() async {
    _stopped = true;
    _renewal?.cancel();
    await _closeSession();
    await _events.close();
  }

  /// Opens a session on [grant] and schedules its renewal.
  Future<void> _open(LiveGrant grant) async {
    final session = openSession(
      LiveSessionConfig(
        model: model,
        targetLanguage: target,
        credentials: grant.credentials!,
      ),
    );
    final subscription = session.events.listen(_onEvent);
    try {
      await session.open();
    } catch (_) {
      await subscription.cancel();
      await session.close();
      rethrow;
    }
    _session = session;
    _subscription = subscription;
    _grant = grant;
    _openedAt = _now();
    final ends =
        grant.expiresAt ?? _now().add(Duration(seconds: grant.blockSec));
    final wait = ends.difference(_now()) - renewAhead;
    _renewal?.cancel();
    _renewal = Timer(wait.isNegative ? Duration.zero : wait, _renew);
  }

  /// Swaps in a session on a fresh block before the current one expires (AC-14.3).
  Future<void> _renew() async {
    if (_stopped) {
      return;
    }
    final grant = await access.request(target: target, mode: mode);
    if (_stopped) {
      return;
    }
    await _closeSession();
    if (!grant.allowed) {
      _emit(LiveCaptionStopped(denial: grant.denial, resetAt: grant.resetAt));
      return;
    }
    try {
      await _open(grant);
    } catch (_) {
      _emit(const LiveCaptionStopped());
    }
  }

  /// Closes the session and reports the seconds it was open.
  Future<void> _closeSession() async {
    final session = _session;
    final grant = _grant;
    final opened = _openedAt;
    _session = null;
    _grant = null;
    _openedAt = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    await session?.close();
    final tokenId = grant?.tokenId;
    if (tokenId != null && opened != null) {
      final used = _now().difference(opened).inSeconds;
      await access.report(tokenId, used.clamp(0, grant!.blockSec));
    }
  }

  /// Turns transcripts into caption updates; a closed or failed session stops Live.
  void _onEvent(LiveEvent event) {
    switch (event) {
      case LiveInputTranscript(:final text):
        _original.write(text);
        _update(done: false);
      case LiveOutputTranscript(:final text):
        _translation.write(text);
        _update(done: false);
      case LiveTurnComplete():
        if (_original.isNotEmpty || _translation.isNotEmpty) {
          _update(done: true);
          _turn++;
          _original.clear();
          _translation.clear();
        }
      case LiveError() || LiveClosed():
        if (!_stopped) {
          _renewal?.cancel();
          unawaited(_closeSession());
          _emit(const LiveCaptionStopped());
        }
      default:
        break;
    }
  }

  /// Emits the current turn's caption.
  void _update({required bool done}) => _emit(
    LiveCaptionUpdate(
      turn: _turn,
      original: _original.toString().trim(),
      translation: _translation.toString().trim(),
      done: done,
    ),
  );

  /// Adds an event unless closed.
  void _emit(LiveCaptionEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}

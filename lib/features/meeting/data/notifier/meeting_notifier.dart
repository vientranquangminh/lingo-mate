import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/audio/audio_capture.dart';
import '../../../../core/audio/audio_frame.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/background/background_capture.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/live/live_captioner.dart';
import '../../../../core/engines/live/live_access.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/engines/translate/gemini_text_translator.dart';
import '../../../../core/phrases/phrase_repository.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../../../core/settings/user_settings.dart';
import '../../../../generated/l10n.dart';
import '../model/meeting_models.dart';
import '../state/meeting_state.dart';

/// Milliseconds on a monotonic clock, for line times.
final meetingClockProvider = Provider<int Function()>((ref) {
  final clock = Stopwatch()..start();
  return () => clock.elapsedMilliseconds;
});

/// The Meeting session; kept alive so captions go on while the user is elsewhere in the app or outside it.
final meetingProvider = NotifierProvider<MeetingNotifier, MeetingState>(
  MeetingNotifier.new,
);

/// Runs Meeting: raw mic in the foreground service → segments → ASR → translation, mirrored in the caption overlay and the in-app transcript (F-04).
class MeetingNotifier extends Notifier<MeetingState> {
  static const contextLines = 3;
  static const overlayLines = 8;
  static const turnGapMs = 3000;

  late final SessionRepository _sessions;
  late final AnalyticsService _analytics;
  late final int Function() _clock;
  ProviderSubscription<AsyncValue<EngineSelection>>? _selection;
  AudioPipeline? _pipeline;
  BackgroundCapture? _background;
  final _subscriptions = <StreamSubscription<Object>>[];
  Future<void> _queue = Future.value();
  Future<String>? _sessionId;
  Future<void> _writes = Future.value();
  int _sessionStartMs = 0;
  int? _lastSegmentEndMs;
  int _nextId = 0;
  List<MeetingLine> _overlaySent = const [];
  EngineSelection? _lastSelection;
  bool _liveOff = false;
  LiveCaptioner? _live;
  SpeechRecognizerEngine? _recognizer;
  final _liveLines = <int, (int id, int startMs)>{};

  @override
  MeetingState build() {
    _sessions = ref.read(sessionRepositoryProvider);
    _analytics = ref.read(analyticsProvider);
    _clock = ref.read(meetingClockProvider);
    ref.onDispose(_dispose);
    final pair = ref.read(userSettingsProvider).pair;
    final initial = MeetingState(source: pair.b, target: pair.a);
    final current = _watchSelection(initial);
    _lastSelection = current;
    return initial.copyWith(
      engine: () => current == null ? null : _engineOf(current),
      blocked: current?.blocked ?? const {},
    );
  }

  /// Follows the engine choice for [languages]; returns the current one.
  EngineSelection? _watchSelection(MeetingState languages) {
    _selection?.close();
    final subscription = ref.listen(
      engineSelectionProvider(_request(languages)),
      (_, next) => next.whenData(_onSelection),
    );
    _selection = subscription;
    return subscription.read().value;
  }

  /// The engine request for [languages].
  EngineRequest _request(MeetingState languages) => EngineRequest(
    mode: SessionMode.meeting,
    pair: LanguagePair(languages.source, languages.target),
  );

  /// Sets the meeting language; only while stopped.
  void setSource(String source) {
    if (state.running || source == state.source || source == state.target) {
      return;
    }
    state = state.copyWith(source: source);
    final current = _watchSelection(state);
    if (current != null) {
      _onSelection(current);
    }
  }

  /// Starts the foreground service, the overlay when [overlay] is allowed, and capture (AC-04.2, AC-04.3).
  Future<void> start({required bool overlay}) async {
    if (state.running || state.starting) {
      return;
    }
    state = state.copyWith(starting: true, block: () => null);
    try {
      final recognizer = await ref
          .read(speechRecognizerProvider.future)
          .catchError((Object _) => null);
      if (!ref.mounted) {
        return;
      }
      if (recognizer == null) {
        state = state.copyWith(block: () => MeetingBlock.noSpeechModel);
        return;
      }
      final vadFactory = await ref
          .read(vadFactoryProvider.future)
          .catchError((Object _) => EnergyVoiceActivityDetector.new);
      final background = ref.read(backgroundCaptureProvider);
      await ref.read(notificationPermissionProvider)();
      await background.startService();
      _background = background;
      _subscriptions.add(background.events.listen(_onBackgroundEvent));
      final pipeline = AudioPipeline(
        capture: ref.read(audioCaptureProvider),
        vad: vadFactory(),
        echoGate: EchoGate(nowMs: _clock),
      );
      if (!await pipeline.start(const AudioCaptureConfig.meeting())) {
        await pipeline.dispose();
        await _release();
        if (ref.mounted) {
          state = state.copyWith(block: () => MeetingBlock.micDenied);
        }
        return;
      }
      if (!ref.mounted) {
        await pipeline.dispose();
        await _release();
        return;
      }
      _pipeline = pipeline;
      _lastSegmentEndMs = null;
      _recognizer = recognizer;
      if (state.engine != EngineKind.live || !await _startLive(pipeline)) {
        _listenToSegments(pipeline, recognizer);
      }
      if (!ref.mounted) {
        return;
      }
      final shown = overlay && await background.showOverlay();
      state = state.copyWith(
        running: true,
        overlayShown: shown,
        inAppOnly: !shown,
        lines: const [],
      );
      _pushOverlay();
    } finally {
      if (ref.mounted) {
        state = state.copyWith(starting: false);
      }
    }
  }

  /// Stops capture, removes the overlay and notification and saves the session (AC-04.8).
  Future<void> stop() async {
    final session = _sessionId;
    _sessionId = null;
    await _release();
    if (session != null) {
      unawaited(
        _analytics.sessionEnd(
          mode: SessionMode.meeting.name,
          durationSec: (_clock() - _sessionStartMs) ~/ 1000,
        ),
      );
      final writes = _writes;
      await writes
          .then((_) async => _sessions.finish(await session))
          .catchError((Object _) {});
    }
    if (ref.mounted) {
      state = state.copyWith(running: false, overlayShown: false);
    }
  }

  /// Shows or hides the overlay while running.
  Future<void> setOverlay(bool on) async {
    final background = _background;
    if (!state.running || background == null) {
      return;
    }
    if (on) {
      final shown = await background.showOverlay();
      state = state.copyWith(overlayShown: shown, inAppOnly: !shown);
      _overlaySent = const [];
      _pushOverlay();
    } else {
      await background.hideOverlay();
      state = state.copyWith(overlayShown: false);
    }
  }

  /// Saves [line] to the phrasebook; returns whether it was new (AC-04.5).
  Future<bool> save(MeetingLine line) async {
    final translation = line.translation;
    if (translation == null) {
      return false;
    }
    final result = await ref
        .read(phraseRepositoryProvider)
        .save(
          sourceLang: line.from,
          sourceText: line.original,
          targetLang: line.to,
          targetText: translation,
        );
    final saved = result.outcome == SaveOutcome.saved;
    if (saved) {
      unawaited(_analytics.phraseSaved(source: 'meeting'));
    }
    if (ref.mounted) {
      state = state.copyWith(savedCount: state.savedCount + 1);
    }
    return saved;
  }

  /// The engine Meeting uses: Live while it works, else the text engines.
  EngineKind? _engineOf(EngineSelection selection) =>
      selection.engine == EngineKind.live && !_liveOff
      ? EngineKind.live
      : selection.conversationEngine;

  /// Uses the text engines from now on, e.g. after declining sign-in for Live (AC-13.6).
  void skipLive() {
    _liveOff = true;
    final selection = _lastSelection;
    if (selection != null) {
      _onSelection(selection);
    }
  }

  /// Captions the meeting through on-device speech recognition and text translation.
  void _listenToSegments(
    AudioPipeline pipeline,
    SpeechRecognizerEngine recognizer,
  ) {
    _subscriptions.add(
      pipeline.segments.listen(
        (segment) =>
            _queue = _queue.then((_) => _onSegment(recognizer, segment)),
      ),
    );
  }

  /// Streams the meeting audio to Live Translate; false, with the reason in the state, when Live is refused or fails (F-05).
  Future<bool> _startLive(AudioPipeline pipeline) async {
    final captioner = LiveCaptioner(
      access: ref.read(liveAccessProvider),
      openSession: ref.read(liveSessionOpenerProvider),
      model: ref.read(engineRemoteConfigProvider).modelLiveTranslate,
      target: state.target,
      mode: SessionMode.meeting,
    );
    if (!await captioner.start()) {
      final denial = captioner.denial;
      await captioner.stop();
      if (ref.mounted) {
        state = state.copyWith(
          liveDenial: denial,
          liveStops: state.liveStops + 1,
        );
        skipLive();
      }
      return false;
    }
    _live = captioner;
    _subscriptions
      ..add(pipeline.liveChunks.listen(captioner.send))
      ..add(captioner.events.listen(_onLiveEvent));
    return true;
  }

  /// Shows a Live line as it grows; a finished turn is saved.
  void _onLiveEvent(LiveCaptionEvent event) {
    if (!ref.mounted || !state.running && _live == null) {
      return;
    }
    switch (event) {
      case LiveCaptionUpdate(
        :final turn,
        :final original,
        :final translation,
        :final done,
      ):
        final now = _clock();
        var entry = _liveLines[turn];
        if (entry == null) {
          _ensureSession();
          final line = MeetingLine(
            id: _nextId++,
            from: state.source,
            to: state.target,
            original: original,
            atMs: (now - _sessionStartMs).clamp(0, 1 << 31),
            engine: EngineKind.live,
          );
          entry = (line.id, now);
          _liveLines[turn] = entry;
          state = state.copyWith(lines: [...state.lines, line]);
        }
        final (id, startMs) = entry;
        _update(
          id,
          (l) => l.copyWith(
            original: original,
            translation: translation,
            engine: EngineKind.live,
            status: done
                ? MeetingLineStatus.translated
                : MeetingLineStatus.translating,
          ),
        );
        _pushOverlay();
        if (done) {
          _liveLines.remove(turn);
          _record(id, startMs, now);
        }
      case LiveCaptionAudio():
        break;
      case LiveCaptionStopped(:final denial):
        unawaited(_fallBackFromLive(denial));
    }
  }

  /// Leaves Live for the text engines and keeps captioning (AC-14.2).
  Future<void> _fallBackFromLive(LiveDenial? denial) async {
    final live = _live;
    _live = null;
    _liveLines.clear();
    await live?.stop();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(liveDenial: denial, liveStops: state.liveStops + 1);
    skipLive();
    final pipeline = _pipeline;
    final recognizer = _recognizer;
    if (state.running && pipeline != null && recognizer != null) {
      _listenToSegments(pipeline, recognizer);
    }
  }

  /// Stops capture, the overlay and the service.
  Future<void> _release() async {
    final live = _live;
    _live = null;
    _liveLines.clear();
    await live?.stop();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final pipeline = _pipeline;
    _pipeline = null;
    await pipeline?.dispose();
    final background = _background;
    _background = null;
    if (background != null) {
      await background.hideOverlay();
      await background.stopService();
    }
    _overlaySent = const [];
  }

  /// Stops on Stop from the notification or overlay; saves lines long-pressed in the overlay.
  void _onBackgroundEvent(BackgroundEvent event) {
    switch (event) {
      case BackgroundStopPressed():
        unawaited(stop());
      case OverlayLineLongPressed(:final index, :final text):
        final sent = _overlaySent;
        final line = index != null && index >= 0 && index < sent.length
            ? sent[index]
            : sent.where((l) => l.shown == text).lastOrNull;
        if (line != null) {
          unawaited(save(line));
        }
    }
  }

  /// Tracks the engine and clears a no-engine block once one is back.
  void _onSelection(EngineSelection selection) {
    _lastSelection = selection;
    final engine = _engineOf(selection);
    state = state.copyWith(
      engine: () => engine,
      blocked: selection.blocked,
      block: () => engine != null && state.block == MeetingBlock.noEngine
          ? null
          : state.block,
    );
    _pushOverlay(force: true);
  }

  /// Recognises one segment and adds its line, marking a new turn after a long pause.
  Future<void> _onSegment(
    SpeechRecognizerEngine recognizer,
    AudioSegment segment,
  ) async {
    if (!ref.mounted || !state.running) {
      return;
    }
    final last = _lastSegmentEndMs;
    _lastSegmentEndMs = segment.endMs;
    try {
      await recognizer.ensureReady(state.source);
      final result = await recognizer.transcribe(
        segment,
        hintLang: state.source,
      );
      final text = result.text.trim();
      if (text.isEmpty || !ref.mounted || !state.running) {
        return;
      }
      final endMs = _clock();
      _ensureSession();
      final line = MeetingLine(
        id: _nextId++,
        from: state.source,
        to: state.target,
        original: text,
        atMs: (endMs - segment.durationMs - _sessionStartMs).clamp(0, 1 << 31),
        newTurn:
            state.lines.isNotEmpty &&
            last != null &&
            segment.startMs - last >= turnGapMs,
      );
      state = state.copyWith(lines: [...state.lines, line]);
      _pushOverlay();
      await _translate(line);
      _pushOverlay();
      _record(line.id, endMs - segment.durationMs, endMs);
    } catch (_) {
      return;
    }
  }

  /// Translates [line] on the current engine, falling back to Offline when Standard fails.
  Future<void> _translate(MeetingLine line) async {
    final engine = state.engine;
    if (engine == null) {
      _update(line.id, (l) => l.copyWith(status: MeetingLineStatus.paused));
      state = state.copyWith(block: () => MeetingBlock.noEngine);
      return;
    }
    final request = TranslateRequest(
      from: line.from,
      to: line.to,
      text: line.original,
      context: [
        for (final l in state.lines.where((l) => l.id != line.id)) l.original,
      ].reversed.take(contextLines).toList().reversed.toList(),
    );
    Translation? translation;
    var fallback = false;
    try {
      translation = await ref
          .read(textTranslatorProvider(engine))
          .translate(request);
      if (engine == EngineKind.standard) {
        ref.read(errorBurstProvider).recordSuccess();
      }
    } catch (error) {
      if (engine == EngineKind.standard) {
        await _onStandardFailure(error);
        translation = await _offlineFallback(request);
        fallback = translation != null;
      }
    }
    if (!ref.mounted) {
      return;
    }
    if (translation == null) {
      _update(line.id, (l) => l.copyWith(status: MeetingLineStatus.failed));
      return;
    }
    _update(
      line.id,
      (l) => l.copyWith(
        translation: translation!.text,
        engine: translation.engine,
        fallback: fallback,
        status: MeetingLineStatus.translated,
      ),
    );
  }

  /// Records a Standard failure; a region refusal blocks cloud engines for 24 h (AC-05.5).
  Future<void> _onStandardFailure(Object error) async {
    final now = DateTime.now();
    if (GeminiTextTranslator.isRegionBlocked(error)) {
      await ref.read(regionBlockProvider.notifier).block(now);
    } else {
      ref.read(errorBurstProvider).recordFailure(now);
    }
    if (ref.mounted) {
      ref.invalidate(engineSelectionProvider(_request(state)));
    }
  }

  /// Translates on Offline when its models are there, for one line.
  Future<Translation?> _offlineFallback(TranslateRequest request) async {
    final offline = ref.read(textTranslatorProvider(EngineKind.offline));
    try {
      if (!await offline.isAvailable(request.from, request.to)) {
        return null;
      }
      return await offline.translate(request);
    } catch (_) {
      return null;
    }
  }

  /// Sends the latest lines and the engine to the overlay when it shows something new.
  void _pushOverlay({bool force = false}) {
    final background = _background;
    if (background == null || !state.overlayShown) {
      return;
    }
    final lines = state.lines.length <= overlayLines
        ? state.lines
        : state.lines.sublist(state.lines.length - overlayLines);
    if (!force && _sameLines(lines, _overlaySent)) {
      return;
    }
    _overlaySent = lines;
    final engine = state.engine;
    unawaited(
      background
          .updateOverlay(
            [
              for (final line in lines)
                OverlayLine(original: line.original, translation: line.shown),
            ],
            engine: engine?.name ?? '',
            engineLabel: engine == null ? '' : _engineLabel(engine),
          )
          .catchError((Object _) {}),
    );
  }

  /// Whether two line lists show the same text.
  static bool _sameLines(List<MeetingLine> a, List<MeetingLine> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  /// Returns the engine name in the app language, for the overlay header.
  String _engineLabel(EngineKind engine) {
    final code =
        ref.read(userSettingsProvider).appLocale ??
        PlatformDispatcher.instance.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == code,
    );
    final l10n = lookupAppLocalizations(Locale(supported ? code : 'en'));
    return switch (engine) {
      EngineKind.offline => l10n.engineOffline,
      EngineKind.standard => l10n.engineStandard,
      EngineKind.live => l10n.engineLive,
    };
  }

  /// Starts the saved session on the first line (F-07).
  void _ensureSession() {
    if (_sessionId != null) {
      return;
    }
    _sessionStartMs = _clock();
    final pair = LanguagePair(state.source, state.target);
    _sessionId = _sessions.start(
      mode: SessionMode.meeting,
      engine: state.engine,
      pair: pair,
    );
    unawaited(
      _analytics.sessionStart(
        mode: SessionMode.meeting.name,
        engine: state.engine?.name ?? 'none',
        pair: '${pair.a}-${pair.b}',
      ),
    );
  }

  /// Queues the line with [id] for saving, translated or not.
  void _record(int id, int startMs, int endMs) {
    final line = state.lines.where((l) => l.id == id).firstOrNull;
    final session = _sessionId;
    if (line == null || session == null) {
      return;
    }
    final utterance = NewUtterance(
      speaker: null,
      sourceLang: line.from,
      sourceText: line.original,
      targetLang: line.to,
      targetText: line.translation ?? '',
      startMs: (startMs - _sessionStartMs).clamp(0, 1 << 31),
      endMs: (endMs - _sessionStartMs).clamp(0, 1 << 31),
      engine: UtteranceEngine.of(line.engine, fallback: line.fallback),
      latencyMs: line.status == MeetingLineStatus.translated
          ? _clock() - endMs
          : null,
    );
    _writes = _writes.then((_) async {
      try {
        await _sessions.addUtterance(await session, utterance);
      } catch (_) {
        return;
      }
    });
  }

  /// Replaces the line with [id] by [change] applied.
  void _update(int id, MeetingLine Function(MeetingLine) change) {
    state = state.copyWith(
      lines: [for (final l in state.lines) l.id == id ? change(l) : l],
    );
  }

  /// Releases capture and the service when the provider goes away.
  void _dispose() {
    _selection?.close();
    unawaited(_release());
  }
}

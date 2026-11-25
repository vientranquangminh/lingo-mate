import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/audio/audio_frame.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/pcm_player.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/asr/partial_transcriber.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/live/live_access.dart';
import '../../../../core/engines/live/live_captioner.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/engines/translate/cloud_hearing.dart';
import '../../../../core/engines/translate/gemini_text_translator.dart';
import '../../../../core/engines/tts/speech_synthesizer.dart';
import '../../../../core/sessions/session_repository.dart';
import '../model/conversation_models.dart';
import '../state/conversation_state.dart';

/// Milliseconds on a monotonic clock, for the echo gate tail.
final conversationClockProvider = Provider<int Function()>((ref) {
  final clock = Stopwatch()..start();
  return () => clock.elapsedMilliseconds;
});

/// The conversation for one language pair; disposed when the screen closes.
final conversationProvider = NotifierProvider.autoDispose
    .family<ConversationNotifier, ConversationState, LanguagePair>(
      ConversationNotifier.new,
    );

/// Runs conversation turns, tap-to-talk or auto: mic → ASR → translate on the selected engine → TTS, with echo gating (F-02).
class ConversationNotifier extends Notifier<ConversationState> {
  ConversationNotifier(this.pair);

  static const contextTurns = 3;

  final LanguagePair pair;

  late final EchoGate _gate;
  late final SpeechSynthesizerEngine _tts;
  late final SessionRepository _sessions;
  late final int Function() _clock;
  late final AnalyticsService _analytics;
  Future<String>? _sessionId;
  Future<void> _writes = Future.value();
  final _utteranceIds = <int, Future<String?>>{};
  int _sessionStartMs = 0;
  AudioPipeline? _pipeline;
  StreamSubscription<AudioSegment>? _segments;
  StreamSubscription<AudioSegment>? _partials;
  Future<void> _queue = Future.value();
  int _nextId = 0;
  EngineSelection? _lastSelection;
  bool _liveOff = false;
  final _live = <LiveCaptioner>[];
  final _liveSubscriptions = <StreamSubscription<Object>>[];
  final _liveTurns = <(Speaker, int), (int id, int startMs)>{};
  PcmPlayer? _player;
  int _playbackEndsAtMs = 0;
  Timer? _gateTimer;

  EngineRequest get _request =>
      EngineRequest(mode: SessionMode.conversation, pair: pair);

  @override
  ConversationState build() {
    _clock = ref.read(conversationClockProvider);
    _gate = EchoGate(nowMs: _clock);
    _sessions = ref.read(sessionRepositoryProvider);
    _analytics = ref.read(analyticsProvider);
    _tts = ref.read(speechSynthesizerProvider);
    ref.onDispose(_dispose);
    final current = ref
        .listen(
          engineSelectionProvider(_request),
          (_, next) => next.whenData(_onSelection),
        )
        .read()
        .value;
    _lastSelection = current;
    return ConversationState(
      pair: pair,
      engine: current == null ? null : _engineOf(current),
      blocked: current?.blocked ?? const {},
    );
  }

  /// The engine Conversation uses: Live (two-way, one open mic) while it works, else the text engines.
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

  /// Starts listening for [speaker], or stops when that side is already listening; leaves auto mode. On Live, starts or stops two-way Live.
  Future<void> toggleMic(Speaker speaker) async {
    if (state.engine == EngineKind.live) {
      await _toggleLive();
      return;
    }
    final current = state.listening;
    await _stopListening();
    if (!ref.mounted) {
      return;
    }
    if (current == speaker) {
      state = state.copyWith(draft: () => null);
      return;
    }
    if (state.speaking) {
      await _tts.stop();
    }
    await _openMic(
      (recognizer, segment) async {
        await _stopListening();
        await _recognize(speaker, recognizer, segment);
      },
      onOpen: () => state = state.copyWith(listening: () => speaker),
      partialLang: state.languageOf(speaker),
    );
  }

  /// Turns auto mode on (one open mic, each utterance assigned to A or B by language, AC-02.5) or off.
  Future<void> toggleAuto() async {
    if (state.engine == EngineKind.live) {
      await _toggleLive();
      return;
    }
    final wasAuto = state.auto;
    await _stopListening();
    if (wasAuto || !ref.mounted) {
      return;
    }
    await _openMic(
      (recognizer, segment) =>
          _queue = _queue.then((_) => _onAutoSegment(recognizer, segment)),
      onOpen: () => state = state.copyWith(auto: true),
    );
  }

  /// Starts or stops two-way Live: one Live Translate session into each language on the same mic, spoken aloud with the mic gated (F-05, OQ-4).
  Future<void> _toggleLive() async {
    if (state.liveListening) {
      await _stopLive();
      if (ref.mounted) {
        state = state.copyWith(auto: false);
      }
      return;
    }
    final access = ref.read(liveAccessProvider);
    final open = ref.read(liveSessionOpenerProvider);
    final model = ref.read(engineRemoteConfigProvider).modelLiveTranslate;
    final captioners = [
      for (final speaker in Speaker.values)
        LiveCaptioner(
          access: access,
          openSession: open,
          model: model,
          target: state.languageOf(speaker.other),
          mode: SessionMode.conversation,
        ),
    ];
    for (final captioner in captioners) {
      if (!await captioner.start()) {
        final denial = captioner.denial;
        for (final c in captioners) {
          await c.stop();
        }
        if (ref.mounted) {
          state = state.copyWith(
            liveDenial: denial,
            liveStops: state.liveStops + 1,
          );
          skipLive();
          await toggleAuto();
        }
        return;
      }
    }
    final pipeline = AudioPipeline(
      capture: ref.read(audioCaptureProvider),
      vad: EnergyVoiceActivityDetector(),
      echoGate: _gate,
    );
    if (!await pipeline.start()) {
      for (final c in captioners) {
        await c.stop();
      }
      await pipeline.dispose();
      if (ref.mounted) {
        state = state.copyWith(paused: () => PauseReason.micDenied);
      }
      return;
    }
    if (!ref.mounted) {
      for (final c in captioners) {
        await c.stop();
      }
      await pipeline.dispose();
      return;
    }
    final player = ref.read(livePlayerProvider);
    await player.start().catchError((Object _) {});
    _player = player;
    _pipeline = pipeline;
    _live.addAll(captioners);
    _liveSubscriptions.add(
      pipeline.liveChunks.listen((chunk) {
        for (final c in _live) {
          c.send(chunk);
        }
      }),
    );
    for (final (i, speaker) in Speaker.values.indexed) {
      _liveSubscriptions.add(
        captioners[i].events.listen((e) => _onLiveEvent(speaker, e)),
      );
    }
    state = state.copyWith(auto: true, paused: () => null);
  }

  /// Shows a Live turn for [speaker] as it grows and plays its speech; a stop falls back to the text engines.
  void _onLiveEvent(Speaker speaker, LiveCaptionEvent event) {
    if (!ref.mounted) {
      return;
    }
    switch (event) {
      case LiveCaptionUpdate(
        :final turn,
        :final original,
        :final translation,
        :final done,
      ):
        if (translation.isEmpty) {
          return;
        }
        final now = _clock();
        var entry = _liveTurns[(speaker, turn)];
        if (entry == null) {
          _ensureSession();
          final created = ConversationTurn(
            id: _nextId++,
            speaker: speaker,
            from: state.languageOf(speaker),
            to: state.languageOf(speaker.other),
            original: original,
            engine: EngineKind.live,
          );
          entry = (created.id, now);
          _liveTurns[(speaker, turn)] = entry;
          state = state.copyWith(turns: [...state.turns, created]);
        }
        final (id, startMs) = entry;
        _updateTurn(
          id,
          (t) => t.copyWith(
            original: original,
            translation: translation,
            engine: EngineKind.live,
            status: done ? TurnStatus.translated : TurnStatus.translating,
          ),
        );
        if (done) {
          _liveTurns.remove((speaker, turn));
          _record(id, startMs, now);
        }
      case LiveCaptionAudio(:final pcm24k):
        if (state.speakOn) {
          unawaited(_player?.write(pcm24k).catchError((Object _) {}));
          _holdGate(pcm24k);
        }
      case LiveCaptionStopped(:final denial):
        unawaited(_fallBackFromLive(denial));
    }
  }

  /// Keeps the mic gated until the queued Live speech has played.
  void _holdGate(Uint8List pcm24k) {
    final now = _clock();
    final durationMs = pcm24k.length ~/ 2 * 1000 ~/ 24000;
    _playbackEndsAtMs =
        (_playbackEndsAtMs > now ? _playbackEndsAtMs : now) + durationMs;
    _gate.setSpeaking(true);
    state = state.copyWith(speaking: true);
    _gateTimer?.cancel();
    _gateTimer = Timer(Duration(milliseconds: _playbackEndsAtMs - now), () {
      _gate.setSpeaking(false);
      if (ref.mounted) {
        state = state.copyWith(speaking: false);
      }
    });
  }

  /// Leaves Live for the text engines and keeps listening in auto mode (AC-14.2).
  Future<void> _fallBackFromLive(LiveDenial? denial) async {
    final wasListening = state.liveListening;
    await _stopLive();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      auto: false,
      liveDenial: denial,
      liveStops: state.liveStops + 1,
    );
    skipLive();
    if (wasListening) {
      await toggleAuto();
    }
  }

  /// Stops the Live sessions, the mic and playback.
  Future<void> _stopLive() async {
    _gateTimer?.cancel();
    _gateTimer = null;
    _gate.setSpeaking(false);
    for (final s in _liveSubscriptions) {
      await s.cancel();
    }
    _liveSubscriptions.clear();
    final live = [..._live];
    _live.clear();
    for (final c in live) {
      await c.stop();
    }
    _liveTurns.clear();
    final pipeline = _pipeline;
    _pipeline = null;
    await pipeline?.dispose();
    final player = _player;
    _player = null;
    await player?.stop().catchError((Object _) {});
    if (ref.mounted && state.speaking) {
      state = state.copyWith(speaking: false);
    }
  }

  /// Opens the mic and routes each segment to [onSegment]; [onOpen] runs once the mic is live; with [partialLang], shows the words heard so far.
  Future<void> _openMic(
    Future<void> Function(SpeechRecognizerEngine, AudioSegment) onSegment, {
    required void Function() onOpen,
    String? partialLang,
  }) async {
    final recognizer = await ref
        .read(speechRecognizerProvider.future)
        .catchError((Object _) => null);
    if (!ref.mounted) {
      return;
    }
    if (recognizer == null) {
      state = state.copyWith(paused: () => PauseReason.noSpeechModel);
      return;
    }
    final vadFactory = await ref
        .read(vadFactoryProvider.future)
        .catchError((Object _) => EnergyVoiceActivityDetector.new);
    final pipeline = AudioPipeline(
      capture: ref.read(audioCaptureProvider),
      vad: vadFactory(),
      echoGate: _gate,
    );
    if (!await pipeline.start()) {
      await pipeline.dispose();
      if (ref.mounted) {
        state = state.copyWith(paused: () => PauseReason.micDenied);
      }
      return;
    }
    if (!ref.mounted) {
      await pipeline.dispose();
      return;
    }
    _pipeline = pipeline;
    final partialAsr = PartialTranscriber(
      recognizer,
      onText: (text) => state = state.copyWith(draft: () => text),
      isIdle: () => ref.mounted && state.listening != null,
    );
    _segments = pipeline.segments.listen((segment) {
      partialAsr.finish();
      unawaited(onSegment(recognizer, segment));
    });
    if (partialLang != null && recognizer.supportsPartials) {
      _partials = pipeline.partials.listen(
        (snapshot) => unawaited(partialAsr.add(snapshot, partialLang)),
      );
    }
    state = state.copyWith(
      paused: () =>
          state.paused == PauseReason.micDenied ||
              state.paused == PauseReason.noSpeechModel
          ? null
          : state.paused,
    );
    onOpen();
  }

  /// Assigns an auto-mode utterance to the side whose language was heard; when unsure, to the person who did not speak last.
  Future<void> _onAutoSegment(
    SpeechRecognizerEngine recognizer,
    AudioSegment segment,
  ) async {
    if (!ref.mounted || !state.auto) {
      return;
    }
    final detected = await recognizer
        .detectLanguage(segment, candidates: [pair.a, pair.b])
        .catchError((Object _) => null);
    final speaker = switch (detected) {
      final lang? when lang == pair.a => Speaker.a,
      final lang? when lang == pair.b => Speaker.b,
      _ => state.turns.lastOrNull?.speaker.other ?? Speaker.a,
    };
    await _recognize(speaker, recognizer, segment);
  }

  /// Turns spoken translations on or off.
  Future<void> setSpeakOn(bool value) async {
    state = state.copyWith(speakOn: value);
    if (!value && state.speaking) {
      await _tts.stop();
    }
  }

  /// Speaks a turn's translation again.
  Future<void> replay(ConversationTurn turn) async {
    final text = turn.translation;
    if (text != null) {
      await _speak(text, turn.to);
    }
  }

  /// Speaks [text] in [lang] with the mic gated, as for a translation (F-19).
  Future<void> speakText(String text, String lang) => _speak(text, lang);

  /// Tracks the engine; a change mid-session raises the switched notice (AC-02.7).
  void _onSelection(EngineSelection selection) {
    _lastSelection = selection;
    final engine = _engineOf(selection);
    final previous = state.engine;
    final switched = previous != null && engine != null && engine != previous;
    if (switched && _sessionId != null) {
      final reason = selection.blocked[previous];
      unawaited(
        _analytics.engineSwitch(
          from: previous.name,
          to: engine.name,
          reason: reason?.name ?? 'auto',
        ),
      );
    }
    state = state.copyWith(
      engine: () => engine,
      blocked: selection.blocked,
      switchedTo: switched ? engine : null,
      switchCount: switched ? state.switchCount + 1 : null,
      paused: () => engine != null && state.paused == PauseReason.noEngine
          ? null
          : state.paused,
    );
  }

  /// Recognises one utterance of [speaker] and translates it.
  Future<void> _recognize(
    Speaker speaker,
    SpeechRecognizerEngine recognizer,
    AudioSegment segment,
  ) async {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(processing: true);
    final from = state.languageOf(speaker);
    try {
      final to = state.languageOf(speaker.other);
      final (:handled, :heard) = await hearOnCloud(
        ref,
        engine: state.engine,
        segment: segment,
        from: [from],
        to: to,
        context: [for (final t in state.turns) t.original].reversed
            .take(contextTurns)
            .toList()
            .reversed
            .toList(),
      );
      final String text;
      if (handled) {
        text = heard?.original ?? '';
      } else {
        await recognizer.ensureReady(from);
        final result = await recognizer.transcribe(segment, hintLang: from);
        text = result.text.trim();
      }
      if (text.isEmpty || !ref.mounted) {
        return;
      }
      final turn = ConversationTurn(
        id: _nextId++,
        speaker: speaker,
        from: from,
        to: to,
        original: text,
        translation: heard?.translation,
        engine: heard == null ? null : EngineKind.standard,
        status: heard == null ? TurnStatus.translating : TurnStatus.translated,
      );
      state = state.copyWith(turns: [...state.turns, turn], draft: () => null);
      final endMs = _clock();
      _ensureSession();
      if (heard == null) {
        await _translate(turn);
      }
      _record(turn.id, endMs - segment.durationMs, endMs);
      final translation = state.turns
          .where((t) => t.id == turn.id)
          .firstOrNull
          ?.translation;
      if (translation != null && state.speakOn) {
        state = state.copyWith(processing: false);
        await _speak(translation, turn.to);
      }
    } catch (_) {
      return;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(processing: false, draft: () => null);
      }
    }
  }

  /// Translates [turn] on the current engine, falling back to Offline when Standard fails (doc 03 §6.2).
  Future<void> _translate(ConversationTurn turn) async {
    final engine = state.engine;
    if (engine == null) {
      _updateTurn(turn.id, (t) => t.copyWith(status: TurnStatus.paused));
      state = state.copyWith(paused: () => PauseReason.noEngine);
      return;
    }
    final request = TranslateRequest(
      from: turn.from,
      to: turn.to,
      text: turn.original,
      context: [
        for (final t in state.turns.where((t) => t.id != turn.id)) t.original,
      ].reversed.take(contextTurns).toList().reversed.toList(),
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
      _updateTurn(turn.id, (t) => t.copyWith(status: TurnStatus.failed));
      return;
    }
    _updateTurn(
      turn.id,
      (t) => t.copyWith(
        translation: translation!.text,
        engine: translation.engine,
        fallback: fallback,
        status: TurnStatus.translated,
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
      ref.invalidate(engineSelectionProvider(_request));
    }
  }

  /// Translates on Offline when its models are there, for one utterance.
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

  /// Speaks [text] with the mic gated until playback ends plus the tail (AC-02.4).
  Future<void> _speak(String text, String lang) async {
    _gate.setSpeaking(true);
    state = state.copyWith(speaking: true);
    try {
      await _tts.speak(text, lang: lang);
    } catch (_) {
      return;
    } finally {
      _gate.setSpeaking(false);
      if (ref.mounted) {
        state = state.copyWith(speaking: false);
      }
    }
  }

  /// Stops the mic, if it is open.
  Future<void> _stopListening() async {
    final pipeline = _pipeline;
    _pipeline = null;
    await _segments?.cancel();
    _segments = null;
    final partials = _partials;
    _partials = null;
    if (partials != null) {
      await partials.cancel();
    }
    if (pipeline != null) {
      await pipeline.dispose();
    }
    if (ref.mounted && (state.listening != null || state.auto)) {
      state = state.copyWith(listening: () => null, auto: false);
    }
  }

  /// Starts the saved session on the first utterance (F-07).
  void _ensureSession() {
    if (_sessionId != null) {
      return;
    }
    _sessionStartMs = _clock();
    _sessionId = _sessions.start(
      mode: SessionMode.conversation,
      engine: state.engine,
      pair: pair,
    );
    unawaited(
      _analytics.sessionStart(
        mode: SessionMode.conversation.name,
        engine: state.engine?.name ?? 'none',
        pair: '${pair.a}-${pair.b}',
      ),
    );
  }

  /// Queues the turn with [id] for saving, translated or not, so captured text is kept (AC-02.8).
  void _record(int id, int startMs, int endMs) {
    final turn = state.turns.where((t) => t.id == id).firstOrNull;
    final session = _sessionId;
    if (turn == null || session == null) {
      return;
    }
    final utterance = NewUtterance(
      speaker: turn.speaker.name,
      sourceLang: turn.from,
      sourceText: turn.original,
      targetLang: turn.to,
      targetText: turn.translation ?? '',
      startMs: (startMs - _sessionStartMs).clamp(0, 1 << 31),
      endMs: (endMs - _sessionStartMs).clamp(0, 1 << 31),
      engine: UtteranceEngine.of(turn.engine, fallback: turn.fallback),
      latencyMs: turn.status == TurnStatus.translated ? _clock() - endMs : null,
    );
    final saved = Completer<String?>();
    _utteranceIds[id] = saved.future;
    _writes = _writes.then((_) async {
      try {
        saved.complete(await _sessions.addUtterance(await session, utterance));
      } catch (_) {
        saved.complete(null);
      }
    });
  }

  /// Returns the stored utterance id of turn [turnId] once it is written, so a saved phrase links to its session (AC-08.1).
  Future<String?> utteranceIdFor(int turnId) =>
      _utteranceIds[turnId] ?? Future.value();

  /// Replaces the turn with [id] by [change] applied.
  void _updateTurn(int id, ConversationTurn Function(ConversationTurn) change) {
    state = state.copyWith(
      turns: [for (final t in state.turns) t.id == id ? change(t) : t],
    );
  }

  /// Releases the mic, stops speech and saves the session with its duration and engine summary (AC-02.10).
  void _dispose() {
    unawaited(_stopLive());
    unawaited(_segments?.cancel());
    unawaited(_partials?.cancel());
    unawaited(_pipeline?.dispose());
    unawaited(_tts.stop().catchError((Object _) {}));
    final session = _sessionId;
    if (session != null) {
      unawaited(
        _analytics.sessionEnd(
          mode: SessionMode.conversation.name,
          durationSec: (_clock() - _sessionStartMs) ~/ 1000,
        ),
      );
      unawaited(
        _writes
            .then((_) async => _sessions.finish(await session))
            .catchError((Object _) {}),
      );
    }
  }
}

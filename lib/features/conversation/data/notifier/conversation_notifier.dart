import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_frame.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/engines/translate/gemini_text_translator.dart';
import '../../../../core/engines/tts/speech_synthesizer.dart';
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
  AudioPipeline? _pipeline;
  StreamSubscription<AudioSegment>? _segments;
  Future<void> _queue = Future.value();
  int _nextId = 0;

  EngineRequest get _request =>
      EngineRequest(mode: SessionMode.conversation, pair: pair);

  @override
  ConversationState build() {
    _gate = EchoGate(nowMs: ref.read(conversationClockProvider));
    _tts = ref.read(speechSynthesizerProvider);
    ref.onDispose(_dispose);
    ref.listen(
      engineSelectionProvider(_request),
      (_, next) => next.whenData(_onSelection),
      fireImmediately: true,
    );
    return ConversationState(pair: pair);
  }

  /// Starts listening for [speaker], or stops when that side is already listening; leaves auto mode.
  Future<void> toggleMic(Speaker speaker) async {
    final current = state.listening;
    await _stopListening();
    if (current == speaker || !ref.mounted) {
      return;
    }
    if (state.speaking) {
      await _tts.stop();
    }
    await _openMic((recognizer, segment) async {
      await _stopListening();
      await _recognize(speaker, recognizer, segment);
    }, onOpen: () => state = state.copyWith(listening: () => speaker));
  }

  /// Turns auto mode on (one open mic, each utterance assigned to A or B by language, AC-02.5) or off.
  Future<void> toggleAuto() async {
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

  /// Opens the mic and routes each segment to [onSegment]; [onOpen] runs once the mic is live.
  Future<void> _openMic(
    Future<void> Function(SpeechRecognizerEngine, AudioSegment) onSegment, {
    required void Function() onOpen,
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
    _segments = pipeline.segments.listen(
      (segment) => onSegment(recognizer, segment),
    );
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

  /// Tracks the engine; a change mid-session raises the switched notice (AC-02.7).
  void _onSelection(EngineSelection selection) {
    final engine = _conversationEngine(selection);
    final previous = state.engine;
    final switched = previous != null && engine != null && engine != previous;
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

  /// Maps Live to the text engines until two-way Live is settled (OQ-4, AC-02.9).
  static EngineKind? _conversationEngine(EngineSelection selection) {
    if (selection.engine != EngineKind.live) {
      return selection.engine;
    }
    for (final engine in [EngineKind.standard, EngineKind.offline]) {
      if (!selection.blocked.containsKey(engine)) {
        return engine;
      }
    }
    return null;
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
      await recognizer.ensureReady(from);
      final result = await recognizer.transcribe(segment, hintLang: from);
      final text = result.text.trim();
      if (text.isEmpty || !ref.mounted) {
        return;
      }
      final turn = ConversationTurn(
        id: _nextId++,
        speaker: speaker,
        from: from,
        to: state.languageOf(speaker.other),
        original: text,
      );
      state = state.copyWith(turns: [...state.turns, turn]);
      await _translate(turn);
    } catch (_) {
      return;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(processing: false);
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
    if (state.speakOn) {
      await _speak(translation.text, turn.to);
    }
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
    if (pipeline != null) {
      await pipeline.dispose();
    }
    if (ref.mounted && (state.listening != null || state.auto)) {
      state = state.copyWith(listening: () => null, auto: false);
    }
  }

  /// Replaces the turn with [id] by [change] applied.
  void _updateTurn(int id, ConversationTurn Function(ConversationTurn) change) {
    state = state.copyWith(
      turns: [for (final t in state.turns) t.id == id ? change(t) : t],
    );
  }

  /// Releases the mic and stops speech.
  void _dispose() {
    unawaited(_segments?.cancel());
    unawaited(_pipeline?.dispose());
    unawaited(_tts.stop().catchError((Object _) {}));
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/audio/audio_frame.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/engines/translate/gemini_text_translator.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../../../core/settings/user_settings.dart';
import '../model/listen_models.dart';
import '../state/listen_state.dart';

/// Milliseconds on a monotonic clock, for caption times.
final listenClockProvider = Provider<int Function()>((ref) {
  final clock = Stopwatch()..start();
  return () => clock.elapsedMilliseconds;
});

/// The Listen session for a source and target language; disposed when the screen closes.
final listenProvider = NotifierProvider.autoDispose
    .family<ListenNotifier, ListenState, LanguagePair>(ListenNotifier.new);

/// Runs Listen: one open mic → segments → on-device ASR in the source language → translation into the user's language, as a caption list (F-03).
class ListenNotifier extends Notifier<ListenState> {
  ListenNotifier(this.languages);

  static const contextCaptions = 3;

  final LanguagePair languages;

  late final SessionRepository _sessions;
  late final AnalyticsService _analytics;
  late final int Function() _clock;
  ProviderSubscription<AsyncValue<EngineSelection>>? _selection;
  AudioPipeline? _pipeline;
  StreamSubscription<AudioSegment>? _segments;
  Future<void> _queue = Future.value();
  Future<String>? _sessionId;
  Future<void> _writes = Future.value();
  int _sessionStartMs = 0;
  int _nextId = 0;

  @override
  ListenState build() {
    _sessions = ref.read(sessionRepositoryProvider);
    _analytics = ref.read(analyticsProvider);
    _clock = ref.read(listenClockProvider);
    ref.onDispose(_dispose);
    final initial = ListenState(source: languages.a, target: languages.b);
    final current = _watchSelection(initial.source);
    return initial.copyWith(
      engine: () => current?.conversationEngine,
      blocked: current?.blocked ?? const {},
    );
  }

  /// The languages Auto picks the speaker's language from: the user's partner languages, else English.
  List<String> get autoCandidates {
    final settings = ref.read(userSettingsProvider);
    final candidates = [
      for (final lang in settings.partnerLanguages)
        if (lang != languages.b) lang,
    ];
    if (candidates.isEmpty) {
      candidates.add(languages.b == 'en' ? 'vi' : 'en');
    }
    return candidates;
  }

  /// The language engines are chosen for: the picked source, or Auto's first candidate.
  String _engineSource(String source) =>
      source == listenAutoSource ? autoCandidates.first : source;

  /// Follows the engine choice for [source]; returns the current one.
  EngineSelection? _watchSelection(String source) {
    _selection?.close();
    final request = EngineRequest(
      mode: SessionMode.listen,
      pair: LanguagePair(_engineSource(source), languages.b),
    );
    final subscription = ref.listen(
      engineSelectionProvider(request),
      (_, next) => next.whenData(_onSelection),
    );
    _selection = subscription;
    return subscription.read().value;
  }

  /// Changes the speaker's language; the next captions use it.
  void setSource(String source) {
    if (source == state.source) {
      return;
    }
    state = state.copyWith(source: source);
    final current = _watchSelection(source);
    if (current != null) {
      _onSelection(current);
    }
  }

  /// Opens the mic and starts captioning (AC-03.1), or resumes after a pause.
  Future<void> start() async {
    if (state.listening) {
      return;
    }
    final recognizer = await ref
        .read(speechRecognizerProvider.future)
        .catchError((Object _) => null);
    if (!ref.mounted) {
      return;
    }
    if (recognizer == null) {
      state = state.copyWith(block: () => ListenBlock.noSpeechModel);
      return;
    }
    final vadFactory = await ref
        .read(vadFactoryProvider.future)
        .catchError((Object _) => EnergyVoiceActivityDetector.new);
    final pipeline = AudioPipeline(
      capture: ref.read(audioCaptureProvider),
      vad: vadFactory(),
      echoGate: EchoGate(nowMs: _clock),
    );
    if (!await pipeline.start()) {
      await pipeline.dispose();
      if (ref.mounted) {
        state = state.copyWith(block: () => ListenBlock.micDenied);
      }
      return;
    }
    if (!ref.mounted) {
      await pipeline.dispose();
      return;
    }
    _pipeline = pipeline;
    _segments = pipeline.segments.listen(
      (segment) => _queue = _queue.then((_) => _onSegment(recognizer, segment)),
    );
    state = state.copyWith(
      started: true,
      listening: true,
      block: () => state.block == ListenBlock.noEngine ? state.block : null,
    );
  }

  /// Stops the mic and keeps the captions; nothing is heard or counted until [start] (AC-03.6).
  Future<void> pause() async {
    final pipeline = _pipeline;
    _pipeline = null;
    await _segments?.cancel();
    _segments = null;
    await pipeline?.dispose();
    if (ref.mounted && state.listening) {
      state = state.copyWith(listening: false);
    }
  }

  /// Tracks the engine; a change mid-session raises the switched notice.
  void _onSelection(EngineSelection selection) {
    final engine = selection.conversationEngine;
    final previous = state.engine;
    final switched =
        state.started &&
        previous != null &&
        engine != null &&
        engine != previous;
    if (switched && _sessionId != null) {
      unawaited(
        _analytics.engineSwitch(
          from: previous.name,
          to: engine.name,
          reason: selection.blocked[previous]?.name ?? 'auto',
        ),
      );
    }
    state = state.copyWith(
      engine: () => engine,
      blocked: selection.blocked,
      switchedTo: switched ? engine : null,
      switchCount: switched ? state.switchCount + 1 : null,
      block: () => engine != null && state.block == ListenBlock.noEngine
          ? null
          : state.block,
    );
  }

  /// Recognises one segment in the source language and adds its caption.
  Future<void> _onSegment(
    SpeechRecognizerEngine recognizer,
    AudioSegment segment,
  ) async {
    if (!ref.mounted || !state.listening) {
      return;
    }
    try {
      final from = await _languageOf(recognizer, segment);
      await recognizer.ensureReady(from);
      final result = await recognizer.transcribe(segment, hintLang: from);
      final text = result.text.trim();
      if (text.isEmpty || !ref.mounted) {
        return;
      }
      final endMs = _clock();
      _ensureSession();
      final caption = Caption(
        id: _nextId++,
        from: from,
        to: languages.b,
        original: text,
        atMs: (endMs - segment.durationMs - _sessionStartMs).clamp(0, 1 << 31),
      );
      state = state.copyWith(captions: [...state.captions, caption]);
      await _translate(caption);
      _record(caption.id, endMs - segment.durationMs, endMs);
    } catch (_) {
      return;
    }
  }

  /// Returns the picked source language, or the detected one in Auto.
  Future<String> _languageOf(
    SpeechRecognizerEngine recognizer,
    AudioSegment segment,
  ) async {
    if (state.source != listenAutoSource) {
      return state.source;
    }
    final candidates = autoCandidates;
    final detected = await recognizer
        .detectLanguage(segment, candidates: candidates)
        .catchError((Object _) => null);
    return detected ?? candidates.first;
  }

  /// Translates [caption] on the current engine, falling back to Offline when Standard fails.
  Future<void> _translate(Caption caption) async {
    final engine = state.engine;
    if (engine == null) {
      _update(caption.id, (c) => c.copyWith(status: CaptionStatus.paused));
      state = state.copyWith(block: () => ListenBlock.noEngine);
      return;
    }
    final request = TranslateRequest(
      from: caption.from,
      to: caption.to,
      text: caption.original,
      context: [
        for (final c in state.captions.where((c) => c.id != caption.id))
          c.original,
      ].reversed.take(contextCaptions).toList().reversed.toList(),
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
        await _onStandardFailure(error, request);
        translation = await _offlineFallback(request);
        fallback = translation != null;
      }
    }
    if (!ref.mounted) {
      return;
    }
    if (translation == null) {
      _update(caption.id, (c) => c.copyWith(status: CaptionStatus.failed));
      return;
    }
    _update(
      caption.id,
      (c) => c.copyWith(
        translation: translation!.text,
        engine: translation.engine,
        fallback: fallback,
        status: CaptionStatus.translated,
      ),
    );
  }

  /// Records a Standard failure; a region refusal blocks cloud engines for 24 h (AC-05.5).
  Future<void> _onStandardFailure(
    Object error,
    TranslateRequest request,
  ) async {
    final now = DateTime.now();
    if (GeminiTextTranslator.isRegionBlocked(error)) {
      await ref.read(regionBlockProvider.notifier).block(now);
    } else {
      ref.read(errorBurstProvider).recordFailure(now);
    }
    if (ref.mounted) {
      ref.invalidate(
        engineSelectionProvider(
          EngineRequest(
            mode: SessionMode.listen,
            pair: LanguagePair(_engineSource(state.source), languages.b),
          ),
        ),
      );
    }
  }

  /// Translates on Offline when its models are there, for one caption.
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

  /// Starts the saved session on the first caption (F-07).
  void _ensureSession() {
    if (_sessionId != null) {
      return;
    }
    _sessionStartMs = _clock();
    final pair = LanguagePair(_engineSource(state.source), languages.b);
    _sessionId = _sessions.start(
      mode: SessionMode.listen,
      engine: state.engine,
      pair: pair,
    );
    unawaited(
      _analytics.sessionStart(
        mode: SessionMode.listen.name,
        engine: state.engine?.name ?? 'none',
        pair: '${pair.a}-${pair.b}',
      ),
    );
  }

  /// Queues the caption with [id] for saving, translated or not.
  void _record(int id, int startMs, int endMs) {
    final caption = state.captions.where((c) => c.id == id).firstOrNull;
    final session = _sessionId;
    if (caption == null || session == null) {
      return;
    }
    final utterance = NewUtterance(
      speaker: null,
      sourceLang: caption.from,
      sourceText: caption.original,
      targetLang: caption.to,
      targetText: caption.translation ?? '',
      startMs: (startMs - _sessionStartMs).clamp(0, 1 << 31),
      endMs: (endMs - _sessionStartMs).clamp(0, 1 << 31),
      engine: UtteranceEngine.of(caption.engine, fallback: caption.fallback),
      latencyMs: caption.status == CaptionStatus.translated
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

  /// Replaces the caption with [id] by [change] applied.
  void _update(int id, Caption Function(Caption) change) {
    state = state.copyWith(
      captions: [for (final c in state.captions) c.id == id ? change(c) : c],
    );
  }

  /// Releases the mic and saves the session.
  void _dispose() {
    _selection?.close();
    unawaited(_segments?.cancel());
    unawaited(_pipeline?.dispose());
    final session = _sessionId;
    if (session != null) {
      unawaited(
        _analytics.sessionEnd(
          mode: SessionMode.listen.name,
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

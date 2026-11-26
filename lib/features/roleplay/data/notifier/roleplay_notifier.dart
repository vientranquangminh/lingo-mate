import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/audio_frame.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/learning/learning_assistant.dart';
import '../../../../core/learning/learning_models.dart';
import '../state/roleplay_state.dart';

/// A roleplay scene: the situation and the two languages.
class RoleplayScene extends Equatable {
  const RoleplayScene({
    required this.situation,
    required this.targetLang,
    required this.userLang,
  });

  final String situation;
  final String targetLang;
  final String userLang;

  @override
  List<Object?> get props => [situation, targetLang, userLang];
}

/// The roleplay of one scene; disposed when the screen closes.
final roleplayProvider = NotifierProvider.autoDispose
    .family<RoleplayNotifier, RoleplayState, RoleplayScene>(
      RoleplayNotifier.new,
    );

/// Runs a roleplay: the partner opens, the learner answers by text or voice, and each answer gets feedback (AC-22.1).
class RoleplayNotifier extends Notifier<RoleplayState> {
  RoleplayNotifier(this.scene);

  final RoleplayScene scene;
  AudioPipeline? _pipeline;
  StreamSubscription<AudioSegment>? _segments;

  @override
  RoleplayState build() {
    ref.onDispose(_stopListening);
    return const RoleplayState();
  }

  /// Lets the partner open the scene when nothing was said yet.
  Future<void> open() async {
    if (state.messages.isEmpty && !state.waiting) {
      await _partnerTurn();
    }
  }

  /// Sends the learner's [text] and waits for the partner's answer.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.waiting) {
      return;
    }
    state = state.copyWith(
      messages: [
        ...state.messages,
        RoleplayMessage(fromLearner: true, text: trimmed),
      ],
      heard: () => null,
    );
    await _partnerTurn();
  }

  /// Asks again after a failure.
  Future<void> retry() => _partnerTurn();

  /// Gets the partner's next line and attaches feedback to the learner's last line.
  Future<void> _partnerTurn() async {
    state = state.copyWith(waiting: true, failed: false);
    try {
      final turn = await ref
          .read(learningAssistantProvider)
          .roleplay(
            situation: scene.situation,
            messages: state.messages,
            targetLang: scene.targetLang,
            userLang: scene.userLang,
          );
      if (!ref.mounted) {
        return;
      }
      final messages = [...state.messages];
      if (messages.isNotEmpty && messages.last.fromLearner) {
        messages.last = messages.last.withFeedback(turn.feedback);
      }
      state = state.copyWith(
        waiting: false,
        messages: [
          ...messages,
          RoleplayMessage(
            fromLearner: false,
            text: turn.reply,
            translation: turn.replyTranslation,
          ),
        ],
      );
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(waiting: false, failed: true);
      }
    }
  }

  /// Listens for one spoken answer in the target language and puts its text in [RoleplayState.heard].
  Future<void> listen() async {
    if (state.listening) {
      await _stopListening();
      return;
    }
    final recognizer = await ref
        .read(speechRecognizerProvider.future)
        .catchError((Object _) => null);
    if (recognizer == null || !ref.mounted) {
      return;
    }
    final vad = await ref
        .read(vadFactoryProvider.future)
        .catchError((Object _) => EnergyVoiceActivityDetector.new);
    final pipeline = AudioPipeline(
      capture: ref.read(audioCaptureProvider),
      vad: vad(),
      echoGate: EchoGate(nowMs: () => DateTime.now().millisecondsSinceEpoch),
    );
    if (!await pipeline.start()) {
      await pipeline.dispose();
      return;
    }
    _pipeline = pipeline;
    state = state.copyWith(listening: true);
    _segments = pipeline.segments.listen((segment) async {
      await _stopListening();
      try {
        await recognizer.ensureReady(scene.targetLang);
        final result = await recognizer.transcribe(
          segment,
          hintLang: scene.targetLang,
        );
        if (ref.mounted && result.text.trim().isNotEmpty) {
          state = state.copyWith(heard: () => result.text.trim());
        }
      } catch (_) {
        return;
      }
    });
  }

  /// Closes the mic.
  Future<void> _stopListening() async {
    final pipeline = _pipeline;
    _pipeline = null;
    await _segments?.cancel();
    _segments = null;
    await pipeline?.dispose();
    if (ref.mounted && state.listening) {
      state = state.copyWith(listening: false);
    }
  }
}

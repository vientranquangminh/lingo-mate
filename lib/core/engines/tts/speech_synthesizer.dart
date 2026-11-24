import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Whether the synthesizer is playing; drives echo gating (doc 03 §5).
enum TtsState { idle, speaking }

/// Speaks translations aloud.
abstract interface class SpeechSynthesizerEngine {
  /// Whether a voice for [lang] is installed.
  Future<bool> supports(String lang);

  /// Speaks [text] in [lang] and completes when playback ends.
  Future<void> speak(String text, {required String lang, double rate = 1.0});

  /// Stops playback.
  Future<void> stop();

  /// Playback state changes.
  Stream<TtsState> get state;
}

/// [SpeechSynthesizerEngine] on the device TTS engine through flutter_tts.
class FlutterTtsSynthesizer implements SpeechSynthesizerEngine {
  FlutterTtsSynthesizer([FlutterTts? tts]) : _tts = tts ?? FlutterTts() {
    _tts
      ..setStartHandler(() => _state.add(TtsState.speaking))
      ..setCompletionHandler(() => _state.add(TtsState.idle))
      ..setCancelHandler(() => _state.add(TtsState.idle))
      ..setErrorHandler((_) => _state.add(TtsState.idle));
  }

  final FlutterTts _tts;
  final _state = StreamController<TtsState>.broadcast();

  @override
  Stream<TtsState> get state => _state.stream;

  @override
  Future<bool> supports(String lang) async {
    try {
      return await _tts.isLanguageAvailable(lang) == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(
    String text, {
    required String lang,
    double rate = 1.0,
  }) async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(0.5 * rate);
    _state.add(TtsState.speaking);
    try {
      await _tts.speak(text);
    } finally {
      _state.add(TtsState.idle);
    }
  }

  @override
  Future<void> stop() => _tts.stop();

  /// Stops playback and closes the state stream.
  Future<void> dispose() async {
    await _tts.stop();
    await _state.close();
  }
}

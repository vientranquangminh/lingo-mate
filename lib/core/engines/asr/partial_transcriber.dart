import 'dart:async';

import '../../audio/audio_frame.dart';
import '../engines.dart';

/// Transcribes speech-so-far snapshots one at a time, dropping results overtaken by the finished utterance.
class PartialTranscriber {
  PartialTranscriber(
    this._recognizer, {
    required this.onText,
    required this.isIdle,
    int Function()? nowMs,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SpeechRecognizerEngine _recognizer;
  final void Function(String text) onText;
  final bool Function() isIdle;
  final int Function() _nowMs;

  int _generation = 0;
  bool _running = false;
  int _restUntilMs = 0;

  /// Transcribes [snapshot] in [lang] unless a run is in progress, final segments are being processed, or the last run's rest has not passed.
  Future<void> add(AudioSegment snapshot, String lang) async {
    if (_running || !isIdle() || _nowMs() < _restUntilMs) {
      return;
    }
    _running = true;
    final generation = _generation;
    final startMs = _nowMs();
    try {
      final result = await _recognizer.transcribe(snapshot, hintLang: lang);
      final text = result.text.trim();
      if (generation == _generation && text.isNotEmpty && isIdle()) {
        onText(text);
      }
    } catch (_) {
      return;
    } finally {
      final endMs = _nowMs();
      _restUntilMs = endMs + (endMs - startMs);
      _running = false;
    }
  }

  /// Discards the result of any run started before the utterance ended.
  void finish() => _generation++;
}

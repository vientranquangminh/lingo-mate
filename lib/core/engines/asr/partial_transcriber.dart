import 'dart:async';

import '../../audio/audio_frame.dart';
import '../engines.dart';

/// Transcribes speech-so-far snapshots one at a time, dropping results overtaken by the finished utterance.
class PartialTranscriber {
  PartialTranscriber(
    this._recognizer, {
    required this.onText,
    required this.isIdle,
  });

  final SpeechRecognizerEngine _recognizer;
  final void Function(String text) onText;
  final bool Function() isIdle;

  int _generation = 0;
  bool _running = false;

  /// Transcribes [snapshot] in [lang] unless a run is in progress or final segments are being processed.
  Future<void> add(AudioSegment snapshot, String lang) async {
    if (_running || !isIdle()) {
      return;
    }
    _running = true;
    final generation = _generation;
    try {
      final result = await _recognizer.transcribe(snapshot, hintLang: lang);
      final text = result.text.trim();
      if (generation == _generation && text.isNotEmpty && isIdle()) {
        onText(text);
      }
    } catch (_) {
      return;
    } finally {
      _running = false;
    }
  }

  /// Discards the result of any run started before the utterance ended.
  void finish() => _generation++;
}

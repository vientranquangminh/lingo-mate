/// Blocks the microphone path while the app's own audio plays, plus a short tail.
class EchoGate {
  EchoGate({required this._nowMs, this.tailMs = 150});

  final int Function() _nowMs;
  final int tailMs;

  bool _speaking = false;
  int? _stoppedAtMs;

  /// Records whether TTS or Live audio is playing through the speaker.
  void setSpeaking(bool speaking) {
    if (_speaking && !speaking) {
      _stoppedAtMs = _nowMs();
    }
    _speaking = speaking;
  }

  /// Whether microphone audio may reach the segmenter now.
  bool get isOpen {
    if (_speaking) {
      return false;
    }
    final stoppedAt = _stoppedAtMs;
    return stoppedAt == null || _nowMs() - stoppedAt >= tailMs;
  }
}

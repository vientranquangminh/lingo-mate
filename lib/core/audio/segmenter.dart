import 'dart:typed_data';

import 'audio_frame.dart';

/// Timing rules for cutting speech into segments (doc 03 §5).
class SegmenterConfig {
  const SegmenterConfig({
    this.speechThreshold = 0.5,
    this.silenceMs = 500,
    this.minSpeechMs = 400,
    this.maxUtteranceMs = 8000,
    this.minPauseForCutMs = 250,
    this.preRollMs = 200,
  });

  final double speechThreshold;
  final int silenceMs;
  final int minSpeechMs;
  final int maxUtteranceMs;
  final int minPauseForCutMs;
  final int preRollMs;
}

/// Groups VAD-scored frames into speech segments.
class Segmenter {
  Segmenter([this.config = const SegmenterConfig()]);

  final SegmenterConfig config;

  final _preRoll = <AudioFrame>[];
  final _frames = <AudioFrame>[];
  final _speech = <bool>[];
  bool _active = false;
  int _trailingSilenceMs = 0;

  /// Adds a frame with its speech probability and returns any finished segments.
  List<AudioSegment> add(AudioFrame frame, double speechProbability) {
    final isSpeech = speechProbability >= config.speechThreshold;
    if (!_active) {
      if (!isSpeech) {
        _pushPreRoll(frame);
        return const [];
      }
      _active = true;
      _frames
        ..addAll(_preRoll)
        ..add(frame);
      _speech
        ..addAll(List.filled(_preRoll.length, false))
        ..add(true);
      _preRoll.clear();
      _trailingSilenceMs = 0;
      return const [];
    }

    _frames.add(frame);
    _speech.add(isSpeech);
    _trailingSilenceMs = isSpeech ? 0 : _trailingSilenceMs + _ms(frame);

    if (_trailingSilenceMs >= config.silenceMs) {
      final segment = _build(0, _lastSpeechIndex() + 1);
      final tail = _frames.sublist(_lastSpeechIndex() + 1);
      _clearActive();
      tail.forEach(_pushPreRoll);
      return [?segment];
    }
    if (_durationMs(0, _frames.length) >= config.maxUtteranceMs) {
      return _cutLongUtterance();
    }
    return const [];
  }

  /// Whether an utterance is in progress.
  bool get isActive => _active;

  /// Returns the utterance in progress so far, if it holds enough speech, without ending it.
  AudioSegment? snapshot() =>
      _active ? _build(0, _lastSpeechIndex() + 1) : null;

  /// Emits the segment in progress, if it holds enough speech, and resets.
  List<AudioSegment> flush() {
    final segment = _active ? _build(0, _lastSpeechIndex() + 1) : null;
    reset();
    return [?segment];
  }

  /// Drops all buffered audio.
  void reset() {
    _clearActive();
    _preRoll.clear();
  }

  /// Splits an over-long utterance at the latest pause, or hard-cuts when none exists.
  List<AudioSegment> _cutLongUtterance() {
    final pause = _latestPause();
    if (pause == null) {
      final segment = _build(0, _frames.length);
      _clearActive();
      return [?segment];
    }
    final (start, end) = pause;
    final cut = (start + end) ~/ 2;
    final segment = _build(0, start);
    final restFrames = _frames.sublist(cut);
    final restSpeech = _speech.sublist(cut);
    _clearActive();
    if (restSpeech.contains(true)) {
      _active = true;
      _frames.addAll(restFrames);
      _speech.addAll(restSpeech);
      final lastSpeech = restSpeech.lastIndexOf(true);
      _trailingSilenceMs = _durationMs(lastSpeech + 1, _frames.length);
    } else {
      restFrames.forEach(_pushPreRoll);
    }
    return [?segment];
  }

  /// Returns the latest run of non-speech frames long enough to cut at, after the first speech.
  (int, int)? _latestPause() {
    final firstSpeech = _speech.indexOf(true);
    (int, int)? latest;
    var runStart = -1;
    for (var i = firstSpeech + 1; i <= _speech.length; i++) {
      final silent = i < _speech.length && !_speech[i];
      if (silent && runStart < 0) {
        runStart = i;
      } else if (!silent && runStart >= 0) {
        if (_durationMs(runStart, i) >= config.minPauseForCutMs) {
          latest = (runStart, i);
        }
        runStart = -1;
      }
    }
    return latest;
  }

  /// Builds a segment from frames [start, end) if it holds at least the minimum speech.
  AudioSegment? _build(int start, int end) {
    if (end <= start) {
      return null;
    }
    var speechMs = 0;
    for (var i = start; i < end; i++) {
      if (_speech[i]) {
        speechMs += _ms(_frames[i]);
      }
    }
    if (speechMs < config.minSpeechMs) {
      return null;
    }
    final frames = _frames.sublist(start, end);
    final total = frames.fold<int>(0, (n, f) => n + f.samples.length);
    final samples = Int16List(total);
    var offset = 0;
    for (final f in frames) {
      samples.setAll(offset, f.samples);
      offset += f.samples.length;
    }
    final durationMs = _durationMs(start, end);
    return AudioSegment(
      samples: samples,
      startMs: frames.first.startMs,
      endMs: frames.last.endMs,
      speechRatio: durationMs == 0 ? 0 : speechMs / durationMs,
    );
  }

  /// Keeps the last [SegmenterConfig.preRollMs] of non-speech audio.
  void _pushPreRoll(AudioFrame frame) {
    _preRoll.add(frame);
    while (_preRoll.isNotEmpty &&
        _preRoll.fold<int>(0, (n, f) => n + _ms(f)) > config.preRollMs) {
      _preRoll.removeAt(0);
    }
  }

  /// Clears the utterance in progress.
  void _clearActive() {
    _active = false;
    _frames.clear();
    _speech.clear();
    _trailingSilenceMs = 0;
  }

  /// Returns the index of the last speech frame of the utterance.
  int _lastSpeechIndex() => _speech.lastIndexOf(true);

  /// Returns the duration of frames [start, end) in milliseconds.
  int _durationMs(int start, int end) {
    var ms = 0;
    for (var i = start; i < end; i++) {
      ms += _ms(_frames[i]);
    }
    return ms;
  }

  /// Returns the duration of one frame in milliseconds.
  static int _ms(AudioFrame frame) =>
      frame.samples.length ~/ AudioFormat.samplesPerMs;
}

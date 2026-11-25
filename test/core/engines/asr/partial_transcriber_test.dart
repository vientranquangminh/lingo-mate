import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/engines/asr/partial_transcriber.dart';
import 'package:lingo_mate/core/engines/asr/whisper_cpp_engine.dart';
import 'package:lingo_mate/core/engines/engines.dart';

/// Recognizer whose results the test completes by hand.
class _ManualRecognizer implements SpeechRecognizerEngine {
  final pending = <Completer<AsrResult>>[];

  @override
  bool get supportsPartials => true;

  @override
  String get id => 'manual';

  @override
  Future<void> ensureReady(String lang) async {}

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) {
    final completer = Completer<AsrResult>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async => null;
}

void main() {
  final snapshot = AudioSegment(
    samples: Int16List(16000),
    startMs: 0,
    endMs: 1000,
    speechRatio: 1,
  );
  late _ManualRecognizer recognizer;
  late List<String> texts;
  late bool idle;
  late PartialTranscriber partials;

  setUp(() {
    recognizer = _ManualRecognizer();
    texts = [];
    idle = true;
    partials = PartialTranscriber(
      recognizer,
      onText: texts.add,
      isIdle: () => idle,
    );
  });

  test('reports the text of a snapshot', () async {
    final run = partials.add(snapshot, 'en');
    recognizer.pending.single.complete(
      const AsrResult(text: ' Hello ', lang: 'en'),
    );
    await run;

    expect(texts, ['Hello']);
  });

  test(
    'skips snapshots while a run is in progress or the pipeline is busy',
    () async {
      unawaited(partials.add(snapshot, 'en'));
      unawaited(partials.add(snapshot, 'en'));
      expect(recognizer.pending, hasLength(1));

      idle = false;
      recognizer.pending.single.complete(
        const AsrResult(text: 'Hi', lang: 'en'),
      );
      await pumpEventQueue();
      await partials.add(snapshot, 'en');

      expect(recognizer.pending, hasLength(1));
      expect(texts, isEmpty);
    },
  );

  test('drops a result that finished after the utterance ended', () async {
    final run = partials.add(snapshot, 'en');
    partials.finish();
    recognizer.pending.single.complete(
      const AsrResult(text: 'Late', lang: 'en'),
    );
    await run;

    expect(texts, isEmpty);
  });

  test('sizes the Whisper encoder context to the audio', () {
    expect(WhisperCppEngine.audioContextFor(16000), 256);
    expect(WhisperCppEngine.audioContextFor(16000 * 10), 564);
    expect(WhisperCppEngine.audioContextFor(16000 * 40), 1500);
  });
}

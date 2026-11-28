import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_capture.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/audio/audio_pipeline.dart';
import 'package:lingo_mate/core/audio/echo_gate.dart';
import 'package:lingo_mate/core/audio/voice_activity_detector.dart';

import 'audio_test_utils.dart';

/// Capture that streams whatever the test pushes.
class _FakeCapture implements AudioCapture {
  _FakeCapture({this.permitted = true});

  final bool permitted;
  final controller = StreamController<Uint8List>();
  bool stopped = false;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async =>
      controller.stream;

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

void main() {
  late _FakeCapture capture;
  late AudioPipeline pipeline;
  late bool speaking;
  late int now;

  setUp(() {
    capture = _FakeCapture();
    speaking = false;
    now = 0;
    final gate = EchoGate(nowMs: () => now);
    pipeline = AudioPipeline(
      capture: capture,
      vad: EnergyVoiceActivityDetector(),
      echoGate: gate,
    );
    addTearDown(pipeline.dispose);
    gate.setSpeaking(speaking);
  });

  test('turns microphone audio into a speech segment', () async {
    final segments = <AudioSegment>[];
    pipeline.segments.listen(segments.add);

    expect(await pipeline.start(), isTrue);
    capture.controller
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await pumpEventQueue();

    expect(segments, hasLength(1));
    expect(segments.single.durationMs, 1000);
  });

  test('returns false and does not record without permission', () async {
    capture = _FakeCapture(permitted: false);
    pipeline = AudioPipeline(
      capture: capture,
      vad: EnergyVoiceActivityDetector(),
      echoGate: EchoGate(nowMs: () => now),
    );

    expect(await pipeline.start(), isFalse);
    expect(pipeline.isRunning, isFalse);
  });

  test('emits no segment for audio heard while the app speaks', () async {
    final segments = <AudioSegment>[];
    pipeline.segments.listen(segments.add);
    await pipeline.start();

    pipeline.echoGate.setSpeaking(true);
    pipeline
      ..addPcm(pcm(1000, amplitude: 4000))
      ..addPcm(pcm(700));
    await pumpEventQueue();

    expect(segments, isEmpty);
  });

  test('stop flushes the segment in progress and stops the mic', () async {
    final segments = <AudioSegment>[];
    pipeline.segments.listen(segments.add);
    await pipeline.start();

    pipeline.addPcm(pcm(800, amplitude: 4000));
    await pipeline.stop();
    await pumpEventQueue();

    expect(segments, hasLength(1));
    expect(capture.stopped, isTrue);
    expect(pipeline.ringBuffer.newestMs, 0);
  });

  test('sends 100 ms chunks to Live listeners', () async {
    final chunks = <Uint8List>[];
    pipeline.liveChunks.listen(chunks.add);
    await pipeline.start();

    pipeline.addPcm(pcm(250, amplitude: 100));
    await pumpEventQueue();

    expect(chunks, hasLength(2));
    expect(chunks.first.length, 100 * AudioFormat.samplesPerMs * 2);
  });

  test('emits the speech so far every 0.7 s while someone speaks', () async {
    final partials = <AudioSegment>[];
    final segments = <AudioSegment>[];
    pipeline.partials.listen(partials.add);
    pipeline.segments.listen(segments.add);
    await pipeline.start();

    pipeline.addPcm(pcm(2500, amplitude: 4000));
    await pumpEventQueue();

    expect(partials, hasLength(3));
    expect(partials.last.durationMs, greaterThan(partials.first.durationMs));
    expect(segments, isEmpty);

    pipeline.addPcm(pcm(700));
    await pumpEventQueue();

    expect(segments, hasLength(1));
    expect(partials, hasLength(3));
  });
}

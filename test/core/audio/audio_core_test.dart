import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/audio/audio_ring_buffer.dart';
import 'package:lingo_mate/core/audio/echo_gate.dart';
import 'package:lingo_mate/core/audio/frame_chunker.dart';
import 'package:lingo_mate/core/audio/latency_timeline.dart';
import 'package:lingo_mate/core/audio/voice_activity_detector.dart';

import 'audio_test_utils.dart';

void main() {
  group('FrameChunker', () {
    test('splits uneven byte chunks into timestamped 20 ms frames', () {
      final chunker = FrameChunker();
      final bytes = pcm(50, amplitude: 7);

      final first = chunker.add(Uint8List.sublistView(bytes, 0, 333));
      final rest = chunker.add(Uint8List.sublistView(bytes, 333));

      final frames = [...first, ...rest];
      expect(frames.map((f) => f.startMs), [0, 20]);
      expect(frames.every((f) => f.samples.every((s) => s == 7)), isTrue);
    });

    test('reads little-endian negative samples', () {
      final chunker = FrameChunker();
      final samples = Int16List(AudioFormat.samplesPerFrame)..[0] = -1234;

      final frame = chunker.add(samples.buffer.asUint8List()).single;

      expect(frame.samples[0], -1234);
    });
  });

  group('EchoGate', () {
    test('closes while speaking and for 150 ms after', () {
      var now = 0;
      final gate = EchoGate(nowMs: () => now);
      expect(gate.isOpen, isTrue);

      gate.setSpeaking(true);
      expect(gate.isOpen, isFalse);

      now = 1000;
      gate.setSpeaking(false);
      now = 1149;
      expect(gate.isOpen, isFalse);

      now = 1150;
      expect(gate.isOpen, isTrue);
    });
  });

  group('AudioRingBuffer', () {
    test('returns audio still held and null for audio overwritten', () {
      final buffer = AudioRingBuffer(capacityMs: 100);
      for (var t = 0; t < 200; t += 20) {
        buffer.add(frameAt(t, amplitude: t));
      }

      expect(buffer.oldestMs, 100);
      expect(buffer.newestMs, 200);
      expect(buffer.read(0, 40), isNull);
      final held = buffer.read(140, 160)!;
      expect(held.length, 20 * AudioFormat.samplesPerMs);
      expect(held.every((s) => s == 140), isTrue);
    });

    test('clear erases everything', () {
      final buffer = AudioRingBuffer(capacityMs: 100)
        ..add(frameAt(0, amplitude: 5))
        ..clear();

      expect(buffer.newestMs, 0);
      expect(buffer.read(0, 20), isNull);
    });
  });

  group('EnergyVoiceActivityDetector', () {
    test('scores loud frames as speech and silence as not', () {
      final vad = EnergyVoiceActivityDetector();

      expect(vad.speechProbability(frameAt(0, amplitude: 3000)), 1);
      expect(vad.speechProbability(frameAt(0, amplitude: 50)), 0);
      expect(vad.speechProbability(frameAt(0)), 0);
    });
  });

  group('LatencyTimeline', () {
    test('reports stage times relative to VAD end', () {
      var now = 500;
      final timeline = LatencyTimeline(nowMs: () => now)
        ..mark(LatencyStage.vadEnd);
      now = 1700;
      timeline.mark(LatencyStage.asrDone);
      now = 2100;
      timeline
        ..mark(LatencyStage.translationShown)
        ..mark(LatencyStage.asrDone);

      expect(timeline.toRow(), {
        'vadEnd': 0,
        'asrDone': 1200,
        'translationShown': 1600,
        'playbackStart': null,
      });
    });
  });
}

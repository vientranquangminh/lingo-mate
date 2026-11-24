import 'dart:async';
import 'dart:typed_data';

import '../../../../core/audio/audio_capture.dart';
import '../../../../core/audio/audio_frame.dart';
import '../../../../core/audio/audio_pipeline.dart';
import '../../../../core/audio/echo_gate.dart';
import '../../../../core/audio/latency_timeline.dart';
import '../../../../core/audio/voice_activity_detector.dart';
import '../../../../core/engines/engines.dart';
import '../model/benchmark_models.dart';

/// Feeds clips through benchmark pipelines as if they came from the mic (doc 07 §5).
class BenchmarkRunner {
  BenchmarkRunner({
    required this._nowMs,
    VoiceActivityDetector Function()? vadFactory,
    this.realTime = true,
  }) : _vadFactory = vadFactory ?? EnergyVoiceActivityDetector.new;

  final int Function() _nowMs;
  final VoiceActivityDetector Function() _vadFactory;
  final bool realTime;

  static const _chunkMs = 100;

  /// Runs one clip's PCM16 bytes through one pipeline and returns a row per utterance.
  Future<List<BenchmarkRow>> runClip({
    required BenchmarkClip clip,
    required Uint8List pcm,
    required BenchmarkPipeline pipeline,
  }) async {
    await pipeline.asr.ensureReady(clip.lang);
    final audio = AudioPipeline(
      capture: const _NoMicCapture(),
      vad: _vadFactory(),
      echoGate: EchoGate(nowMs: _nowMs),
    );
    final rows = <BenchmarkRow>[];
    final context = <String>[];
    var queue = Future<void>.value();
    var index = 0;
    final subscription = audio.segments.listen((segment) {
      final timeline = LatencyTimeline(nowMs: _nowMs)
        ..mark(LatencyStage.vadEnd);
      final utterance = index++;
      queue = queue.then((_) async {
        rows.add(
          await _process(clip, pipeline, segment, timeline, utterance, context),
        );
      });
    });

    const chunkBytes = _chunkMs * AudioFormat.samplesPerMs * 2;
    for (var offset = 0; offset < pcm.length; offset += chunkBytes) {
      final end = (offset + chunkBytes).clamp(0, pcm.length);
      audio.addPcm(Uint8List.sublistView(pcm, offset, end));
      if (realTime) {
        await Future<void>.delayed(const Duration(milliseconds: _chunkMs));
      } else {
        await Future<void>.value();
      }
    }
    await audio.stop();
    await Future<void>.value();
    await queue;
    await subscription.cancel();
    await audio.dispose();
    return rows;
  }

  /// Recognises and translates one segment, timing each stage.
  Future<BenchmarkRow> _process(
    BenchmarkClip clip,
    BenchmarkPipeline pipeline,
    AudioSegment segment,
    LatencyTimeline timeline,
    int utterance,
    List<String> context,
  ) async {
    var transcript = '';
    var translation = '';
    var error = '';
    try {
      final asr = await pipeline.asr.transcribe(segment, hintLang: clip.lang);
      timeline.mark(LatencyStage.asrDone);
      transcript = asr.text;
      final translator = pipeline.translator;
      if (translator != null && transcript.isNotEmpty) {
        final result = await translator.translate(
          TranslateRequest(
            from: clip.lang,
            to: pipeline.targetLang,
            text: transcript,
            context: List.of(
              context.length > 3
                  ? context.sublist(context.length - 3)
                  : context,
            ),
          ),
        );
        timeline.mark(LatencyStage.translationShown);
        translation = result.text;
      }
      context.add(transcript);
    } catch (e) {
      error = e.toString();
    }
    return BenchmarkRow(
      clipId: clip.id,
      lang: clip.lang,
      pipeline: pipeline.id,
      utterance: utterance,
      segmentStartMs: segment.startMs,
      segmentEndMs: segment.endMs,
      asrMs: timeline.sinceVadEnd(LatencyStage.asrDone),
      translationMs: timeline.sinceVadEnd(LatencyStage.translationShown),
      transcript: transcript,
      targetLang: pipeline.translator == null ? '' : pipeline.targetLang,
      translation: translation,
      referenceTranscript: clip.referenceTranscript,
      error: error,
    );
  }
}

/// Capture that never opens the mic; benchmark audio arrives through [AudioPipeline.addPcm].
class _NoMicCapture implements AudioCapture {
  const _NoMicCapture();

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async =>
      const Stream.empty();

  @override
  Future<void> stop() async {}
}

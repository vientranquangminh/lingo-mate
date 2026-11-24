import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:record/record.dart';

import 'audio_frame.dart';

/// Microphone source: speech recognition tuning, or the raw mic for far-field meetings.
enum CaptureSource { voiceRecognition, mic }

/// How the microphone is opened.
class AudioCaptureConfig {
  const AudioCaptureConfig({
    this.source = CaptureSource.voiceRecognition,
    this.noiseSuppression = true,
    this.autoGain = true,
  });

  const AudioCaptureConfig.meeting()
    : source = CaptureSource.mic,
      noiseSuppression = false,
      autoGain = true;

  final CaptureSource source;
  final bool noiseSuppression;
  final bool autoGain;
}

/// Streams 16 kHz mono PCM16 bytes from the microphone.
abstract interface class AudioCapture {
  /// Whether the app may record, asking the user when it may not yet.
  Future<bool> ensurePermission();

  /// Starts recording and returns the PCM16 byte stream.
  Future<Stream<Uint8List>> start(AudioCaptureConfig config);

  /// Stops recording.
  Future<void> stop();
}

/// [AudioCapture] built on the `record` plugin.
@Injectable(as: AudioCapture)
class RecordAudioCapture implements AudioCapture {
  RecordAudioCapture() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) =>
      _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: AudioFormat.sampleRate,
          numChannels: 1,
          noiseSuppress: config.noiseSuppression,
          autoGain: config.autoGain,
          androidConfig: AndroidRecordConfig(
            audioSource: switch (config.source) {
              CaptureSource.voiceRecognition =>
                AndroidAudioSource.voiceRecognition,
              CaptureSource.mic => AndroidAudioSource.mic,
            },
          ),
        ),
      );

  @override
  Future<void> stop() async {
    await _recorder.stop();
  }
}

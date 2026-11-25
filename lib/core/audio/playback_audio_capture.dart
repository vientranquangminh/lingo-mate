import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_capture.dart';

/// [AudioCapture] of what other apps play, through MediaProjection (`MediaCaptureService.kt`, F-21).
class PlaybackAudioCapture implements AudioCapture {
  const PlaybackAudioCapture();

  static const _methods = MethodChannel('lingomate/media_capture');
  static const _audio = EventChannel('lingomate/media_capture/audio');

  @override
  Future<bool> ensurePermission() async {
    try {
      return await _methods.invokeMethod<bool>('requestConsent') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async => _audio
      .receiveBroadcastStream()
      .map((chunk) => chunk is Uint8List ? chunk : Uint8List(0));

  @override
  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stop');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

/// Capture of the phone's own playback.
final mediaCaptureProvider = Provider<AudioCapture>(
  (ref) => const PlaybackAudioCapture(),
);

import 'package:flutter/services.dart';

/// Plays streamed mono PCM16 audio such as Live translations.
abstract interface class PcmPlayer {
  /// Opens playback at [sampleRate].
  Future<void> start({int sampleRate = 24000});

  /// Queues PCM16 bytes.
  Future<void> write(Uint8List bytes);

  /// Stops playback.
  Future<void> stop();
}

/// [PcmPlayer] backed by the native AudioTrack player (`PcmPlayer.kt`).
class NativePcmPlayer implements PcmPlayer {
  const NativePcmPlayer();

  static const _channel = MethodChannel('lingomate/pcm_player');

  @override
  Future<void> start({int sampleRate = 24000}) =>
      _channel.invokeMethod('start', {'sampleRate': sampleRate});

  @override
  Future<void> write(Uint8List bytes) =>
      _channel.invokeMethod('write', {'bytes': bytes});

  @override
  Future<void> stop() => _channel.invokeMethod('stop');
}

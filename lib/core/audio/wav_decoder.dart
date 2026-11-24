import 'dart:typed_data';

import 'audio_frame.dart';

/// Thrown when a WAV file is not 16 kHz mono PCM16.
class WavFormatException implements Exception {
  const WavFormatException(this.message);

  final String message;

  @override
  String toString() => 'WavFormatException: $message';
}

/// Reads the PCM16 data of a 16 kHz mono WAV file.
abstract final class WavDecoder {
  /// Returns the little-endian PCM16 bytes of the `data` chunk.
  static Uint8List decodePcm16(Uint8List bytes) {
    if (bytes.length < 12 ||
        _tag(bytes, 0) != 'RIFF' ||
        _tag(bytes, 8) != 'WAVE') {
      throw const WavFormatException('not a RIFF/WAVE file');
    }
    final data = ByteData.sublistView(bytes);
    var offset = 12;
    var formatChecked = false;
    while (offset + 8 <= bytes.length) {
      final id = _tag(bytes, offset);
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'fmt ') {
        _checkFormat(data, body);
        formatChecked = true;
      } else if (id == 'data') {
        if (!formatChecked) {
          throw const WavFormatException('data chunk before fmt chunk');
        }
        final end = (body + size).clamp(body, bytes.length);
        return Uint8List.sublistView(bytes, body, end);
      }
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    throw const WavFormatException('no data chunk');
  }

  /// Checks the fmt chunk describes 16 kHz mono 16-bit PCM.
  static void _checkFormat(ByteData data, int body) {
    final audioFormat = data.getUint16(body, Endian.little);
    final channels = data.getUint16(body + 2, Endian.little);
    final sampleRate = data.getUint32(body + 4, Endian.little);
    final bits = data.getUint16(body + 14, Endian.little);
    if (audioFormat != 1 ||
        channels != 1 ||
        sampleRate != AudioFormat.sampleRate ||
        bits != 16) {
      throw WavFormatException(
        'expected 16 kHz mono PCM16, got format $audioFormat, '
        '$channels ch, $sampleRate Hz, $bits bit',
      );
    }
  }

  /// Reads a 4-character chunk id.
  static String _tag(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes, offset, offset + 4);
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

import '../../ai/generative_model_factory.dart';
import '../../audio/audio_frame.dart';
import '../engines.dart';
import 'gemini_text_translator.dart';
import 'translator_prompt.dart';

/// Sends a system instruction, a WAV clip and a user message to Gemini and returns its text.
typedef GeminiAudioGenerate = Future<String?> Function({
  required String system,
  required Uint8List wav,
  required String user,
});

/// Standard engine speech path: Gemini hears the sentence and translates it in one call, more accurate than on-device Whisper.
class GeminiSpeechTranslator implements SpeechTranslatorEngine {
  GeminiSpeechTranslator(
    this._generate, {
    this.timeout = const Duration(seconds: 8),
  });

  /// Builds the translator on Firebase AI Logic with the Remote Config model.
  factory GeminiSpeechTranslator.firebase(GenerativeModelFactory factory) =>
      GeminiSpeechTranslator(({
        required system,
        required wav,
        required user,
      }) async {
        final response = await factory
            .speechModel(systemInstruction: system)
            .generateContent([
              Content.multi([InlineDataPart('audio/wav', wav), TextPart(user)]),
            ]);
        return response.text;
      });

  final GeminiAudioGenerate _generate;
  final Duration timeout;

  @override
  Future<SpeechTranslation?> translate({
    required AudioSegment segment,
    required List<String> from,
    required String to,
    List<String> context = const [],
    Map<String, String> glossary = const {},
  }) async {
    final reply = await _generate(
      system: system(from: from, to: to),
      wav: wav(segment.samples),
      user: TranslatorPrompt.user(
        text: 'Transcribe and translate the attached audio.',
        context: context,
        glossary: glossary,
      ),
    ).timeout(timeout);
    return parse(reply, from: from, to: to);
  }

  /// Returns the system instruction for speech in one of [from], translated into [to].
  static String system({required List<String> from, required String to}) =>
      'You are a professional interpreter. The audio is one sentence spoken '
      'in ${from.length == 1 ? from.single : 'one of ${from.join(', ')}'} '
      '(BCP-47 codes). The speaker may have a strong regional accent or '
      'dialect (for Vietnamese: Northern, Central such as Huế, Đà Nẵng or '
      'Quảng Nam, or Southern); listen for what they mean and do not force it '
      'into the standard accent. Write down exactly what was said in that '
      'language with standard spelling, then '
      'translate it into $to. Keep names, numbers and units unchanged. Match '
      'the speaker\'s register. Use the glossary when a term appears. Reply '
      'with JSON only: {"lang": "<code of the spoken language>", '
      '"original": "<transcript>", "translation": "<translation>"}. If there '
      'is no intelligible speech, reply {"lang": "", "original": "", '
      '"translation": ""}.';

  /// Reads Gemini's JSON reply; null when it holds no speech, throws when it is not JSON.
  static SpeechTranslation? parse(
    String? reply, {
    required List<String> from,
    required String to,
  }) {
    final decoded = jsonDecode(reply?.trim() ?? '');
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('expected a JSON object');
    }
    final original = (decoded['original'] as String? ?? '').trim();
    final translation = (decoded['translation'] as String? ?? '').trim();
    if (original.isEmpty) {
      return null;
    }
    if (translation.isEmpty) {
      throw const FormatException('missing translation');
    }
    final lang = decoded['lang'] as String? ?? '';
    return SpeechTranslation(
      lang: from.contains(lang) ? lang : from.first,
      original: original,
      translation: translation,
    );
  }

  /// Whether Gemini refused the request because of the user's location.
  static bool isRegionBlocked(Object error) =>
      GeminiTextTranslator.isRegionBlocked(error);

  /// Wraps 16 kHz mono PCM16 [samples] in a WAV header.
  static Uint8List wav(Int16List samples) {
    final dataBytes = samples.lengthInBytes;
    final header = ByteData(44)
      ..setUint32(0, 0x52494646)
      ..setUint32(4, 36 + dataBytes, Endian.little)
      ..setUint32(8, 0x57415645)
      ..setUint32(12, 0x666d7420)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, AudioFormat.sampleRate, Endian.little)
      ..setUint32(28, AudioFormat.sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461)
      ..setUint32(40, dataBytes, Endian.little);
    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(
            samples.buffer.asUint8List(
              samples.offsetInBytes,
              samples.lengthInBytes,
            ),
          ))
        .takeBytes();
  }
}

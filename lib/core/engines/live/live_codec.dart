import 'dart:convert';
import 'dart:typed_data';

import 'live_models.dart';

/// Builds and parses Live API WebSocket messages (doc 04 §4); field placement is checked in the T-0.5 spike.
abstract final class LiveCodec {
  static const endpoint =
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  /// Returns the WebSocket URI for the session's credentials.
  static Uri uri(LiveCredentials credentials) {
    final base = Uri.parse(endpoint);
    return switch (credentials) {
      LiveApiKey(:final key) => base.replace(queryParameters: {'key': key}),
      LiveEphemeralToken(:final token) => base.replace(
        queryParameters: {'access_token': token},
      ),
    };
  }

  /// Returns the setup message sent first on every connection.
  static String setup(LiveSessionConfig config) {
    final model = config.model.startsWith('models/')
        ? config.model
        : 'models/${config.model}';
    return jsonEncode({
      'setup': {
        'model': model,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
        },
        'inputAudioTranscription': <String, Object>{},
        'outputAudioTranscription': <String, Object>{},
        'translationConfig': {
          'targetLanguageCode': config.targetLanguage,
          'echoTargetLanguage': config.echoTargetLanguage,
        },
        'sessionResumption': {
          if (config.resumptionHandle != null)
            'handle': config.resumptionHandle,
        },
      },
    });
  }

  /// Returns a realtime audio message for 16 kHz mono PCM16 bytes.
  static String audio(Uint8List pcm16k) => jsonEncode({
    'realtimeInput': {
      'audio': {
        'data': base64Encode(pcm16k),
        'mimeType': 'audio/pcm;rate=16000',
      },
    },
  });

  /// Parses one server message, text or binary JSON, into events.
  static List<LiveEvent> decode(Object message) {
    final Object? json;
    try {
      json = jsonDecode(
        message is String ? message : utf8.decode(message as List<int>),
      );
    } catch (_) {
      return const [LiveError('unreadable server message')];
    }
    if (json is! Map<String, dynamic>) {
      return const [];
    }
    final events = <LiveEvent>[];
    if (json.containsKey('setupComplete')) {
      events.add(const LiveReady());
    }
    final content = json['serverContent'];
    if (content is Map<String, dynamic>) {
      final input = _text(content['inputTranscription']);
      if (input != null) {
        events.add(LiveInputTranscript(input));
      }
      final output = _text(content['outputTranscription']);
      if (output != null) {
        events.add(LiveOutputTranscript(output));
      }
      final parts = (content['modelTurn'] as Map<String, dynamic>?)?['parts'];
      if (parts is List) {
        for (final part in parts.whereType<Map<String, dynamic>>()) {
          final inline = part['inlineData'];
          if (inline is Map<String, dynamic> &&
              (inline['mimeType'] as String? ?? '').startsWith('audio/') &&
              inline['data'] is String) {
            events.add(LiveOutputAudio(base64Decode(inline['data'] as String)));
          }
        }
      }
      if (content['turnComplete'] == true) {
        events.add(const LiveTurnComplete());
      }
    }
    final resumption = json['sessionResumptionUpdate'];
    if (resumption is Map<String, dynamic> &&
        resumption['resumable'] != false &&
        resumption['newHandle'] is String) {
      events.add(LiveResumptionHandle(resumption['newHandle'] as String));
    }
    final goAway = json['goAway'];
    if (goAway is Map<String, dynamic>) {
      events.add(LiveGoAway(_duration(goAway['timeLeft'])));
    }
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      events.add(LiveError(error['message'] as String? ?? '$error'));
    }
    return events;
  }

  /// Reads `{text: …}` transcription objects, skipping empty ones.
  static String? _text(Object? value) {
    final text = value is Map<String, dynamic>
        ? value['text'] as String?
        : null;
    return text == null || text.isEmpty ? null : text;
  }

  /// Parses a protobuf duration such as `"9.5s"`.
  static Duration? _duration(Object? value) {
    if (value is! String || !value.endsWith('s')) {
      return null;
    }
    final seconds = double.tryParse(value.substring(0, value.length - 1));
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }
}

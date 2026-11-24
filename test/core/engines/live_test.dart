import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/engines/live/live_codec.dart';
import 'package:lingo_mate/core/engines/live/live_models.dart';
import 'package:lingo_mate/core/engines/live/live_session.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory WebSocket: the test reads what the client sent and pushes server messages.
class _FakeSocket extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeSocket(this.uri);

  final Uri uri;
  final server = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];
  late final _sink = _FakeSink(this);

  @override
  Stream<dynamic> get stream => server.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  /// Pushes a server message as JSON text.
  void push(Map<String, dynamic> json) => server.add(jsonEncode(json));
}

/// Records client messages and closes the fake server stream.
class _FakeSink implements WebSocketSink {
  _FakeSink(this.socket);

  final _FakeSocket socket;
  bool closed = false;

  @override
  void add(dynamic data) =>
      socket.sent.add(jsonDecode(data as String) as Map<String, dynamic>);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    await socket.server.close();
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {}

  @override
  Future<void> get done => Future.value();
}

void main() {
  const config = LiveSessionConfig(
    model: 'gemini-3.5-live-translate-preview',
    targetLanguage: 'en',
    credentials: LiveApiKey('test-key'),
  );

  group('LiveCodec', () {
    test('passes the API key or the ephemeral token in the URI', () {
      expect(LiveCodec.uri(const LiveApiKey('k')).queryParameters, {
        'key': 'k',
      });
      expect(LiveCodec.uri(const LiveEphemeralToken('t')).queryParameters, {
        'access_token': 't',
      });
      expect(
        LiveCodec.uri(const LiveApiKey('k')).path,
        endsWith('v1beta.GenerativeService.BidiGenerateContent'),
      );
    });

    test('builds the setup message from doc 04 §4', () {
      final setup =
          (jsonDecode(LiveCodec.setup(config)) as Map)['setup'] as Map;

      expect(setup['model'], 'models/gemini-3.5-live-translate-preview');
      expect(setup['generationConfig'], {
        'responseModalities': ['AUDIO'],
      });
      expect(setup['translationConfig'], {
        'targetLanguageCode': 'en',
        'echoTargetLanguage': false,
      });
      expect(setup['inputAudioTranscription'], isEmpty);
      expect(setup['sessionResumption'], isEmpty);
    });

    test('adds the resumption handle when resuming', () {
      final setup =
          (jsonDecode(LiveCodec.setup(config.resumeWith('h1'))) as Map)['setup']
              as Map;

      expect(setup['sessionResumption'], {'handle': 'h1'});
    });

    test('encodes audio as base64 16 kHz PCM', () {
      final audio =
          (jsonDecode(LiveCodec.audio(Uint8List.fromList([1, 2, 3])))
                  as Map)['realtimeInput']['audio']
              as Map;

      expect(audio, {'data': 'AQID', 'mimeType': 'audio/pcm;rate=16000'});
    });

    test('decodes transcripts, audio, turn end, handle and goAway', () {
      final events = LiveCodec.decode(
        jsonEncode({
          'serverContent': {
            'inputTranscription': {'text': 'xin chào'},
            'outputTranscription': {'text': 'hello'},
            'modelTurn': {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': 'audio/pcm;rate=24000',
                    'data': base64Encode([9, 8]),
                  },
                },
              ],
            },
            'turnComplete': true,
          },
          'sessionResumptionUpdate': {'newHandle': 'h2', 'resumable': true},
          'goAway': {'timeLeft': '9.5s'},
        }),
      );

      expect(events, [
        const LiveInputTranscript('xin chào'),
        const LiveOutputTranscript('hello'),
        LiveOutputAudio(Uint8List.fromList([9, 8])),
        const LiveTurnComplete(),
        const LiveResumptionHandle('h2'),
        const LiveGoAway(Duration(milliseconds: 9500)),
      ]);
    });

    test('decodes setupComplete from binary frames and ignores empty text', () {
      final events = LiveCodec.decode(
        utf8.encode(
          jsonEncode({
            'setupComplete': <String, Object>{},
            'serverContent': {
              'inputTranscription': {'text': ''},
            },
          }),
        ),
      );

      expect(events, [const LiveReady()]);
    });

    test('skips handles that are not resumable and reports bad JSON', () {
      expect(
        LiveCodec.decode(
          jsonEncode({
            'sessionResumptionUpdate': {'newHandle': 'h', 'resumable': false},
          }),
        ),
        isEmpty,
      );
      expect(LiveCodec.decode('{oops'), [
        const LiveError('unreadable server message'),
      ]);
    });
  });

  group('LiveSession', () {
    late List<_FakeSocket> sockets;
    late LiveSession session;

    setUp(() {
      sockets = [];
      session = LiveSession(
        config,
        connector: (uri) {
          final socket = _FakeSocket(uri);
          sockets.add(socket);
          return socket;
        },
      );
    });

    /// Opens the session and answers the setup message.
    Future<void> openSession() async {
      final opening = session.open();
      await pumpEventQueue();
      sockets.last.push({'setupComplete': <String, Object>{}});
      await opening;
    }

    test('sends setup first and audio only once ready', () async {
      final opening = session.open();
      await pumpEventQueue();
      session.sendAudio(Uint8List(4));
      expect(sockets.single.sent.single.keys, ['setup']);

      sockets.single.push({'setupComplete': <String, Object>{}});
      await opening;
      session.sendAudio(Uint8List(4));

      expect(session.isReady, isTrue);
      expect(sockets.single.sent.last.keys, ['realtimeInput']);
      expect(sockets.single.uri.queryParameters['key'], 'test-key');
    });

    test(
      'fails to open when the server closes before setup completes',
      () async {
        final opening = session.open();
        await pumpEventQueue();
        await sockets.single.server.close();

        await expectLater(opening, throwsStateError);
      },
    );

    test('reconnects with the latest handle on goAway', () async {
      await openSession();
      final events = <LiveEvent>[];
      session.events.listen(events.add);

      sockets.first.push({
        'sessionResumptionUpdate': {'newHandle': 'h7', 'resumable': true},
      });
      sockets.first.push({
        'goAway': {'timeLeft': '5s'},
      });
      await pumpEventQueue();

      expect(sockets, hasLength(2));
      final setup = sockets.last.sent.single['setup'] as Map;
      expect(setup['sessionResumption'], {'handle': 'h7'});
      expect(events.whereType<LiveClosed>(), isEmpty);

      sockets.last.push({'setupComplete': <String, Object>{}});
      await pumpEventQueue();
      expect(session.isReady, isTrue);
    });

    test('reports a server-side close', () async {
      await openSession();
      final events = <LiveEvent>[];
      session.events.listen(events.add);

      await sockets.single.server.close();
      await pumpEventQueue();

      expect(events.last, isA<LiveClosed>());
      expect(session.isReady, isFalse);
    });

    test('close ends the event stream', () async {
      await openSession();
      final done = session.events.toList();

      await session.close();

      expect((await done).last, isA<LiveClosed>());
    });
  });
}

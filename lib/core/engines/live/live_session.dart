import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_codec.dart';
import 'live_models.dart';

/// Opens a WebSocket; replaced by a fake in tests.
typedef LiveConnector = WebSocketChannel Function(Uri uri);

/// One Live Translate connection: sends 100 ms audio chunks, emits [LiveEvent]s and resumes on `goAway`.
class LiveSession {
  LiveSession(this._config, {LiveConnector? connector})
    : _connect = connector ?? WebSocketChannel.connect;

  final LiveConnector _connect;
  LiveSessionConfig _config;
  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  final _events = StreamController<LiveEvent>.broadcast();
  bool _ready = false;
  bool _closing = false;
  bool _reconnecting = false;
  String? _handle;

  /// Server events: transcripts, translated audio, turn ends, errors and close.
  Stream<LiveEvent> get events => _events.stream;

  bool get isReady => _ready;

  /// Connects, sends the setup message and completes once the server confirms it.
  Future<void> open() async {
    final ready = events.firstWhere(
      (e) => e is LiveReady || e is LiveError || e is LiveClosed,
    );
    await _connectChannel();
    final first = await ready;
    if (first is! LiveReady) {
      throw StateError('Live setup failed: $first');
    }
  }

  /// Sends one chunk of 16 kHz mono PCM16; dropped while not ready.
  void sendAudio(Uint8List pcm16k) {
    if (_ready) {
      _channel?.sink.add(LiveCodec.audio(pcm16k));
    }
  }

  /// Closes the connection and the event stream.
  Future<void> close() async {
    _closing = true;
    _ready = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    if (!_events.isClosed) {
      _events.add(const LiveClosed());
      await _events.close();
    }
  }

  /// Opens the socket, listens and sends setup.
  Future<void> _connectChannel() async {
    final channel = _connect(LiveCodec.uri(_config.credentials));
    _channel = channel;
    _subscription = channel.stream.listen(
      _onMessage,
      onError: (Object e) => _emit(LiveError('$e')),
      onDone: () => _onDone(channel),
    );
    await channel.ready;
    channel.sink.add(LiveCodec.setup(_config));
  }

  /// Handles server events, keeping the resumption handle and reconnecting on `goAway`.
  void _onMessage(Object? message) {
    if (message == null) {
      return;
    }
    for (final event in LiveCodec.decode(message)) {
      switch (event) {
        case LiveReady():
          _ready = true;
        case LiveResumptionHandle(:final handle):
          _handle = handle;
        case LiveGoAway():
          unawaited(_reconnect());
        default:
          break;
      }
      _emit(event);
    }
  }

  /// Reports the end of a connection unless it was replaced by a reconnect or closed on purpose.
  void _onDone(WebSocketChannel channel) {
    if (channel != _channel || _closing || _reconnecting) {
      return;
    }
    _ready = false;
    _emit(LiveClosed(code: channel.closeCode, reason: channel.closeReason));
  }

  /// Opens a new connection that resumes the session with the latest handle.
  Future<void> _reconnect() async {
    final handle = _handle;
    if (_reconnecting || _closing || handle == null) {
      return;
    }
    _reconnecting = true;
    _ready = false;
    final old = _channel;
    final oldSubscription = _subscription;
    _config = _config.resumeWith(handle);
    try {
      await _connectChannel();
    } catch (e) {
      _emit(LiveError('reconnect failed: $e'));
    } finally {
      _reconnecting = false;
      await oldSubscription?.cancel();
      await old?.sink.close();
    }
  }

  /// Adds an event unless the stream is closed.
  void _emit(LiveEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}

import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// How a Live session authenticates: the dev API key or a production ephemeral token.
sealed class LiveCredentials extends Equatable {
  const LiveCredentials();
}

/// API key from `.env.dev`; dev flavor only.
class LiveApiKey extends LiveCredentials {
  const LiveApiKey(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

/// Ephemeral token from the `issueLiveToken` Cloud Function (P2).
class LiveEphemeralToken extends LiveCredentials {
  const LiveEphemeralToken(this.token);

  final String token;

  @override
  List<Object?> get props => [token];
}

/// Settings for one Live Translate session.
class LiveSessionConfig extends Equatable {
  const LiveSessionConfig({
    required this.model,
    required this.targetLanguage,
    required this.credentials,
    this.echoTargetLanguage = false,
    this.resumptionHandle,
  });

  final String model;
  final String targetLanguage;
  final LiveCredentials credentials;
  final bool echoTargetLanguage;
  final String? resumptionHandle;

  /// Returns a copy that resumes the session with [handle].
  LiveSessionConfig resumeWith(String handle) => LiveSessionConfig(
    model: model,
    targetLanguage: targetLanguage,
    credentials: credentials,
    echoTargetLanguage: echoTargetLanguage,
    resumptionHandle: handle,
  );

  @override
  List<Object?> get props => [
    model,
    targetLanguage,
    credentials,
    echoTargetLanguage,
    resumptionHandle,
  ];
}

/// Something the Live server reported.
sealed class LiveEvent extends Equatable {
  const LiveEvent();

  @override
  List<Object?> get props => [];
}

/// The server accepted the setup message.
class LiveReady extends LiveEvent {
  const LiveReady();
}

/// Transcript of what the speaker said.
class LiveInputTranscript extends LiveEvent {
  const LiveInputTranscript(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Transcript of the translation the model spoke.
class LiveOutputTranscript extends LiveEvent {
  const LiveOutputTranscript(this.text);

  final String text;

  @override
  List<Object?> get props => [text];
}

/// Translated speech: 24 kHz mono PCM16.
class LiveOutputAudio extends LiveEvent {
  const LiveOutputAudio(this.pcm24k);

  final Uint8List pcm24k;

  @override
  List<Object?> get props => [pcm24k.length];
}

/// The model finished speaking a turn.
class LiveTurnComplete extends LiveEvent {
  const LiveTurnComplete();
}

/// A handle that lets a new connection resume this session.
class LiveResumptionHandle extends LiveEvent {
  const LiveResumptionHandle(this.handle);

  final String handle;

  @override
  List<Object?> get props => [handle];
}

/// The server will close the connection soon; reconnect with the latest handle.
class LiveGoAway extends LiveEvent {
  const LiveGoAway(this.timeLeft);

  final Duration? timeLeft;

  @override
  List<Object?> get props => [timeLeft];
}

/// The session failed.
class LiveError extends LiveEvent {
  const LiveError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// The connection closed.
class LiveClosed extends LiveEvent {
  const LiveClosed({this.code, this.reason});

  final int? code;
  final String? reason;

  @override
  List<Object?> get props => [code, reason];
}

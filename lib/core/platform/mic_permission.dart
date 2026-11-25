import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Where the microphone permission stands.
enum MicPermissionStatus { granted, denied, permanentlyDenied }

/// Reads and requests the microphone permission.
abstract interface class MicPermission {
  /// Returns the current status without asking the user.
  Future<MicPermissionStatus> status();

  /// Shows the system prompt and returns the result.
  Future<MicPermissionStatus> request();
}

/// [MicPermission] on permission_handler.
class HandlerMicPermission implements MicPermission {
  const HandlerMicPermission();

  /// Maps a plugin status to ours.
  static MicPermissionStatus _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted ||
    PermissionStatus.limited => MicPermissionStatus.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => MicPermissionStatus.permanentlyDenied,
    _ => MicPermissionStatus.denied,
  };

  @override
  Future<MicPermissionStatus> status() async =>
      _map(await Permission.microphone.status);

  @override
  Future<MicPermissionStatus> request() async =>
      _map(await Permission.microphone.request());
}

/// Microphone permission access.
final micPermissionProvider = Provider<MicPermission>(
  (ref) => const HandlerMicPermission(),
);

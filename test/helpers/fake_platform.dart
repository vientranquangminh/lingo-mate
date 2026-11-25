import 'package:lingo_mate/core/platform/mic_permission.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';

/// Microphone permission the test controls; counts system prompts.
class FakeMicPermission implements MicPermission {
  FakeMicPermission({
    this.current = MicPermissionStatus.granted,
    this.answer = MicPermissionStatus.granted,
  });

  MicPermissionStatus current;
  MicPermissionStatus answer;
  int requests = 0;

  @override
  Future<MicPermissionStatus> status() async => current;

  @override
  Future<MicPermissionStatus> request() async {
    requests++;
    current = answer;
    return answer;
  }
}

/// Records which system screens were opened.
class FakeSystemSettings implements SystemSettings {
  int appSettingsOpened = 0;
  int voiceInstallsOpened = 0;
  String? shared;

  @override
  Future<bool> installTtsVoice() async {
    voiceInstallsOpened++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }

  @override
  Future<bool> shareText(String text, {String? subject}) async {
    shared = text;
    return true;
  }

  bool screenOn = false;

  @override
  Future<bool> keepScreenOn(bool on) async {
    screenOn = on;
    return true;
  }
}

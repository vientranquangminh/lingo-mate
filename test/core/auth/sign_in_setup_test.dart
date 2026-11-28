import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/auth/firebase_auth_service.dart';
import 'package:lingo_mate/core/engines/live/live_access.dart';

void main() {
  test('Live needs an account unless the build carries its own Gemini key', () {
    ProviderContainer containerWith(LiveAccess access) {
      final c = ProviderContainer(
        overrides: [liveAccessProvider.overrideWithValue(access)],
      );
      addTearDown(c.dispose);
      return c;
    }

    expect(
      containerWith(const DevLiveAccess('key')).read(liveNeedsAccountProvider),
      isFalse,
    );
    expect(
      containerWith(const DevLiveAccess('')).read(liveNeedsAccountProvider),
      isTrue,
    );
  });

  test('Firebase errors that mean the sign-in method is not set up', () {
    expect(
      FirebaseAuthService.isNotConfigured('operation-not-allowed'),
      isTrue,
    );
    expect(
      FirebaseAuthService.isNotConfigured('configuration-not-found'),
      isTrue,
    );
    expect(
      FirebaseAuthService.isNotConfigured('network-request-failed'),
      isFalse,
    );
  });
}

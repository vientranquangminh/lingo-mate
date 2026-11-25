import 'auth_models.dart';

/// Firebase Authentication behind an interface: anonymous start, Google and email link upgrade, sign out (doc 03 §17.1).
abstract interface class AuthService {
  /// Whether accounts work in this build (false without Firebase).
  bool get available;

  /// The current user, null before the first sign-in.
  AppUser? get currentUser;

  /// Emits the user whenever it changes.
  Stream<AppUser?> watchUser();

  /// Signs in anonymously when nobody is signed in (AC-13.1).
  Future<void> ensureSignedIn();

  /// Opens the Google account picker and links it to the anonymous account, or signs in to the account that owns it (AC-13.3, AC-13.4).
  Future<SignInResult> signInWithGoogle();

  /// Sends a passwordless sign-in link to [email] (AC-13.5).
  Future<bool> sendEmailLink(String email);

  /// Completes sign-in with an opened [link]; [email] is needed when it was opened on another device.
  Future<(EmailLinkOutcome, SignInResult?)> completeEmailLink(
    String link, {
    String? email,
  });

  /// Changes the display name of the signed-in user.
  Future<void> updateDisplayName(String name);

  /// Signs out and continues as a new anonymous user (AC-13.11).
  Future<void> signOut();

  /// Signs in again with Google to prove a recent login before deleting the account (AC-13.12).
  Future<SignInResult> reauthenticateWithGoogle();

  /// Asks the server to delete the account and its cloud data, then starts a new anonymous session (AC-13.12).
  Future<AccountDeletion> deleteAccount();
}

/// [AuthService] for builds without Firebase: always anonymous and local.
class LocalOnlyAuthService implements AuthService {
  const LocalOnlyAuthService();

  static const _user = AppUser(
    uid: 'local',
    provider: AuthProviderKind.anonymous,
  );

  @override
  bool get available => false;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() => Stream.value(_user);

  @override
  Future<void> ensureSignedIn() async {}

  @override
  Future<SignInResult> signInWithGoogle() async =>
      const SignInResult(SignInOutcome.unavailable);

  @override
  Future<bool> sendEmailLink(String email) async => false;

  @override
  Future<(EmailLinkOutcome, SignInResult?)> completeEmailLink(
    String link, {
    String? email,
  }) async => (EmailLinkOutcome.notALink, null);

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<SignInResult> reauthenticateWithGoogle() async =>
      const SignInResult(SignInOutcome.unavailable);

  @override
  Future<AccountDeletion> deleteAccount() async => AccountDeletion.failed;
}

import 'dart:async';

import 'package:lingo_mate/core/auth/auth_models.dart';
import 'package:lingo_mate/core/auth/auth_service.dart';

/// Scripted [AuthService] that starts anonymous.
class FakeAuthService implements AuthService {
  FakeAuthService({AppUser? user})
    : _user =
          user ??
          const AppUser(uid: 'anon', provider: AuthProviderKind.anonymous);

  final _changes = StreamController<AppUser?>.broadcast();
  AppUser? _user;
  SignInResult googleResult = const SignInResult(SignInOutcome.linked);
  AppUser googleUser = const AppUser(
    uid: 'anon',
    provider: AuthProviderKind.google,
    displayName: 'Minh Tran',
    email: 'minh@example.com',
  );
  bool sendOk = true;
  final sentTo = <String>[];
  EmailLinkOutcome linkOutcome = EmailLinkOutcome.signedIn;
  String? confirmedEmail;
  int signOuts = 0;

  @override
  bool get available => true;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> watchUser() async* {
    yield _user;
    yield* _changes.stream;
  }

  /// Replaces the user and tells listeners.
  void setUser(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<void> ensureSignedIn() async {}

  @override
  Future<SignInResult> signInWithGoogle() async {
    if (googleResult.succeeded) {
      setUser(googleUser);
    }
    return googleResult;
  }

  @override
  Future<bool> sendEmailLink(String email) async {
    sentTo.add(email);
    return sendOk;
  }

  @override
  Future<(EmailLinkOutcome, SignInResult?)> completeEmailLink(
    String link, {
    String? email,
  }) async {
    confirmedEmail = email;
    if (linkOutcome == EmailLinkOutcome.signedIn) {
      setUser(
        AppUser(uid: 'anon', provider: AuthProviderKind.email, email: email),
      );
      return (linkOutcome, const SignInResult(SignInOutcome.linked));
    }
    return (linkOutcome, null);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    final user = _user!;
    setUser(
      AppUser(
        uid: user.uid,
        provider: user.provider,
        displayName: name,
        email: user.email,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    setUser(const AppUser(uid: 'anon2', provider: AuthProviderKind.anonymous));
  }

  SignInResult reauthResult = const SignInResult(SignInOutcome.signedIn);
  AccountDeletion deletion = AccountDeletion.deleted;
  int reauths = 0;
  int deletions = 0;

  @override
  Future<SignInResult> reauthenticateWithGoogle() async {
    reauths++;
    return reauthResult;
  }

  @override
  Future<AccountDeletion> deleteAccount() async {
    deletions++;
    if (deletion == AccountDeletion.deleted) {
      setUser(
        const AppUser(uid: 'anon3', provider: AuthProviderKind.anonymous),
      );
    }
    return deletion;
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../flavor_config.dart';
import 'auth_models.dart';
import 'auth_service.dart';

/// [AuthService] on Firebase Auth with Google through Credential Manager and passwordless email links.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._prefs) : _auth = FirebaseAuth.instance;

  static const _pendingEmail = 'auth_pending_email';

  final FirebaseAuth _auth;
  final SharedPreferences _prefs;
  bool _googleReady = false;

  @override
  bool get available => true;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> watchUser() => _auth.userChanges().map(_map);

  @override
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  @override
  Future<SignInResult> signInWithGoogle() async {
    try {
      final idToken = await _googleIdToken();
      if (idToken == null) {
        return const SignInResult(SignInOutcome.failed);
      }
      return await _linkOrSignIn(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? const SignInResult(SignInOutcome.cancelled)
          : SignInResult(SignInOutcome.failed, message: e.description);
    } on FirebaseAuthException catch (e) {
      return SignInResult(SignInOutcome.failed, message: e.code);
    }
  }

  @override
  Future<bool> sendEmailLink(String email) async {
    final options = Firebase.app().options;
    try {
      await _auth.sendSignInLinkToEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(
          url: 'https://${options.projectId}.firebaseapp.com/__/auth/links',
          handleCodeInApp: true,
          androidPackageName: _packageName,
          androidInstallApp: true,
          androidMinimumVersion: '26',
        ),
      );
      await _prefs.setString(_pendingEmail, email.trim());
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  @override
  Future<(EmailLinkOutcome, SignInResult?)> completeEmailLink(
    String link, {
    String? email,
  }) async {
    if (!_auth.isSignInWithEmailLink(link)) {
      return (EmailLinkOutcome.notALink, null);
    }
    final address = email ?? _prefs.getString(_pendingEmail);
    if (address == null || address.isEmpty) {
      return (EmailLinkOutcome.needsEmail, null);
    }
    try {
      final result = await _linkOrSignIn(
        EmailAuthProvider.credentialWithLink(email: address, emailLink: link),
      );
      await _prefs.remove(_pendingEmail);
      return (EmailLinkOutcome.signedIn, result);
    } on FirebaseAuthException catch (e) {
      return (
        EmailLinkOutcome.invalid,
        SignInResult(SignInOutcome.failed, message: e.code),
      );
    }
  }

  @override
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut().catchError((Object _) {});
    await _auth.signOut();
    await _auth.signInAnonymously();
  }

  @override
  Future<SignInResult> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      return const SignInResult(SignInOutcome.failed);
    }
    try {
      final idToken = await _googleIdToken();
      if (idToken == null) {
        return const SignInResult(SignInOutcome.cancelled);
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return const SignInResult(SignInOutcome.signedIn);
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled
          ? const SignInResult(SignInOutcome.cancelled)
          : SignInResult(SignInOutcome.failed, message: e.description);
    } on FirebaseAuthException catch (e) {
      return SignInResult(SignInOutcome.failed, message: e.code);
    }
  }

  @override
  Future<AccountDeletion> deleteAccount() async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteAccount')
          .call<void>();
    } on FirebaseFunctionsException catch (e) {
      return e.code == 'failed-precondition' || e.code == 'unauthenticated'
          ? AccountDeletion.needsRecentLogin
          : AccountDeletion.failed;
    }
    await _auth.signOut();
    await _auth.signInAnonymously();
    return AccountDeletion.deleted;
  }

  /// Opens the Google account picker and returns its id token, or null.
  Future<String?> _googleIdToken() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    final account = await google.authenticate();
    return account.authentication.idToken;
  }

  /// Links [credential] to the anonymous user (same uid), or signs in to the account that already owns it.
  Future<SignInResult> _linkOrSignIn(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      await _auth.signInWithCredential(credential);
      return const SignInResult(SignInOutcome.signedIn);
    }
    if (!user.isAnonymous) {
      final before = user.uid;
      final signed = await _auth.signInWithCredential(credential);
      return SignInResult(
        signed.user?.uid == before
            ? SignInOutcome.signedIn
            : SignInOutcome.switchedAccount,
      );
    }
    try {
      await user.linkWithCredential(credential);
      await user.reload();
      return const SignInResult(SignInOutcome.linked);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'credential-already-in-use' &&
          e.code != 'email-already-in-use' &&
          e.code != 'provider-already-linked') {
        rethrow;
      }
      await _auth.signInWithCredential(e.credential ?? credential);
      return const SignInResult(SignInOutcome.switchedAccount);
    }
  }

  /// Maps a Firebase user to [AppUser].
  static AppUser? _map(User? user) {
    if (user == null) {
      return null;
    }
    final providers = user.providerData.map((p) => p.providerId).toSet();
    final provider = user.isAnonymous
        ? AuthProviderKind.anonymous
        : providers.contains('google.com')
        ? AuthProviderKind.google
        : AuthProviderKind.email;
    return AppUser(
      uid: user.uid,
      provider: provider,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
    );
  }

  /// The Android application id of this flavor.
  static String get _packageName => switch (FlavorConfig.instance.appFlavor) {
    Flavor.development => 'com.lingomate.app.dev',
    Flavor.staging => 'com.lingomate.app.staging',
    Flavor.production => 'com.lingomate.app',
  };
}

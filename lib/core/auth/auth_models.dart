import 'package:equatable/equatable.dart';

/// How the user signed in.
enum AuthProviderKind { anonymous, google, email }

/// The signed-in Firebase user as the app sees it.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.provider,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  final String uid;
  final AuthProviderKind provider;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  bool get isAnonymous => provider == AuthProviderKind.anonymous;

  /// Up to two initials from the name, else from the email.
  String get initials {
    final source = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email ?? '').split('@').first;
    final parts = source
        .split(RegExp(r'[\s._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    final letters = parts.length == 1
        ? parts.first.characters(2)
        : '${parts.first.characters(1)}${parts.last.characters(1)}';
    return letters.toUpperCase();
  }

  @override
  List<Object?> get props => [uid, provider, displayName, email, photoUrl];
}

extension on String {
  /// The first [count] user-perceived characters, approximated by runes.
  String characters(int count) => String.fromCharCodes(runes.take(count));
}

/// Why sign-in was asked for; S-24 shows a matching line (AC-13.2).
enum SignInReason { account, sync, live, purchase, restore }

/// What a sign-in attempt ended with.
enum SignInOutcome {
  signedIn,
  linked,
  switchedAccount,
  cancelled,
  failed,
  unavailable,
}

/// The result of a sign-in attempt; [switchedAccount] means the identity belonged to another account (AC-13.4).
class SignInResult extends Equatable {
  const SignInResult(this.outcome, {this.message});

  final SignInOutcome outcome;
  final String? message;

  bool get succeeded => const {
    SignInOutcome.signedIn,
    SignInOutcome.linked,
    SignInOutcome.switchedAccount,
  }.contains(outcome);

  @override
  List<Object?> get props => [outcome, message];
}

/// What happened to an email sign-in link.
enum EmailLinkOutcome { signedIn, needsEmail, invalid, notALink }

/// An opened email link that needs the user, passed to the email link screen.
class EmailLinkRequest extends Equatable {
  const EmailLinkRequest(this.link, this.outcome);

  final String link;
  final EmailLinkOutcome outcome;

  @override
  List<Object?> get props => [link, outcome];
}

/// How an account deletion request ended.
enum AccountDeletion { deleted, needsRecentLogin, failed }

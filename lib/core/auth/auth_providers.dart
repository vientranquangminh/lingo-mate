import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/user_settings.dart';
import 'auth_models.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';

/// Accounts: Firebase when it is set up for this flavor, else local only.
final authServiceProvider = Provider<AuthService>(
  (ref) => Firebase.apps.isEmpty
      ? const LocalOnlyAuthService()
      : FirebaseAuthService(ref.watch(sharedPreferencesProvider)),
);

/// The current user.
final authUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).watchUser(),
);

/// Links the app is opened with, such as email sign-in links.
final incomingLinksProvider = Provider<Stream<Uri>>(
  (ref) => AppLinks().uriLinkStream,
);

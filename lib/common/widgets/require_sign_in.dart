import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/engines/live/live_access.dart';
import '../../navigation/route_const.dart';

/// Returns true at once for a signed-in user (or for Live on a dev build with its own key), else opens S-24 for [reason] and returns whether sign-in succeeded (doc 03 §17.1).
Future<bool> requireSignIn(
  BuildContext context,
  WidgetRef ref,
  SignInReason reason,
) async {
  if (reason == SignInReason.live && !ref.read(liveNeedsAccountProvider)) {
    return true;
  }
  final auth = ref.read(authServiceProvider);
  final user = auth.currentUser;
  if (user != null && !user.isAnonymous) {
    return true;
  }
  if (!auth.available) {
    return false;
  }
  final result = await context.pushNamed<bool>(
    AppRouteName.signIn,
    queryParameters: {'reason': reason.name},
  );
  return result ?? false;
}

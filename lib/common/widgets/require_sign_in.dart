import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_providers.dart';
import '../../navigation/route_const.dart';

/// Returns true at once for a signed-in user, else opens S-24 for [reason] and returns whether sign-in succeeded (doc 03 §17.1).
Future<bool> requireSignIn(
  BuildContext context,
  WidgetRef ref,
  SignInReason reason,
) async {
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

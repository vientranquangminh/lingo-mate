import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../env.dart';
import '../features/authentication/presentation/view/login_page.dart';
import '../core/engines/selection/engine_selector.dart';
import '../features/conversation/presentation/view/conversation_page.dart';
import '../features/devtools/presentation/view/devtools_page.dart';
import '../features/language_packs/presentation/view/language_packs_page.dart';
import 'route_const.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final goRouterProvider = Provider((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Env.devtoolsEnabled
        ? AppRoutePath.devtools
        : AppRoutePath.onboarding,
    routes: [
      GoRoute(
        name: AppRouteName.onboarding,
        path: AppRoutePath.onboarding,
        pageBuilder: (context, state) =>
            CupertinoPage(child: const LoginPage()),
      ),
      GoRoute(
        name: AppRouteName.languagePacks,
        path: AppRoutePath.languagePacks,
        pageBuilder: (context, state) =>
            const CupertinoPage(child: LanguagePacksPage()),
      ),
      GoRoute(
        name: AppRouteName.conversation,
        path: AppRoutePath.conversation,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return CupertinoPage(
            child: ConversationPage(
              pair: LanguagePair(query['a'] ?? 'vi', query['b'] ?? 'en'),
            ),
          );
        },
      ),
      if (Env.devtoolsEnabled)
        GoRoute(
          name: AppRouteName.devtools,
          path: AppRoutePath.devtools,
          pageBuilder: (context, state) =>
              const CupertinoPage(child: DevtoolsPage()),
        ),
    ],
  );
});

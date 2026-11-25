import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_models.dart';
import '../core/engines/selection/engine_selector.dart';
import '../core/settings/user_settings.dart';
import '../env.dart';
import '../features/account/presentation/view/account_page.dart';
import '../features/account/presentation/view/email_link_page.dart';
import '../features/account/presentation/view/email_sign_in_page.dart';
import '../features/account/presentation/view/sign_in_page.dart';
import '../features/conversation/presentation/view/conversation_page.dart';
import '../features/devtools/presentation/view/devtools_page.dart';
import '../features/history/presentation/view/history_page.dart';
import '../features/glossary/presentation/view/glossary_page.dart';
import '../features/glossary/presentation/view/glossary_set_page.dart';
import '../features/history/presentation/view/transcript_page.dart';
import '../features/home/presentation/view/home_page.dart';
import '../features/home/presentation/view/home_shell.dart';
import '../features/language_packs/presentation/view/language_packs_page.dart';
import '../features/learning/presentation/view/phrasing_review_page.dart';
import '../features/listen/presentation/view/listen_page.dart';
import '../features/me/presentation/view/me_page.dart';
import '../features/meeting/presentation/view/meeting_page.dart';
import '../features/me/presentation/view/privacy_page.dart';
import '../features/me/presentation/view/translation_voice_page.dart';
import '../features/onboarding/presentation/view/setup_page.dart';
import '../features/onboarding/presentation/view/welcome_page.dart';
import '../features/phrasebook/presentation/view/add_phrase_page.dart';
import '../features/phrasebook/presentation/view/phrase_detail_page.dart';
import '../features/phrasebook/presentation/view/phrases_page.dart';
import '../features/phrasebook/presentation/view/situation_page.dart';
import '../features/review/presentation/view/review_page.dart';
import '../features/show_mode/presentation/view/show_mode_page.dart';
import 'route_const.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Decides where a location may go: onboarding until it is done, never back to it afterwards (AC-01.5).
String? onboardingRedirect({
  required bool onboardingDone,
  required String location,
}) {
  final inOnboarding =
      location == AppRoutePath.welcome || location == AppRoutePath.setup;
  if (location.startsWith(AppRoutePath.devtools)) {
    return null;
  }
  if (!onboardingDone && !inOnboarding) {
    return AppRoutePath.welcome;
  }
  if (onboardingDone && inOnboarding) {
    return AppRoutePath.home;
  }
  return null;
}

final goRouterProvider = Provider((ref) {
  final onboardingDone = ValueNotifier(
    ref.read(userSettingsProvider).onboardingDone,
  );
  ref
    ..listen(
      userSettingsProvider.select((s) => s.onboardingDone),
      (_, done) => onboardingDone.value = done,
    )
    ..onDispose(onboardingDone.dispose);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: onboardingDone.value
        ? AppRoutePath.home
        : AppRoutePath.welcome,
    refreshListenable: onboardingDone,
    redirect: (context, state) => onboardingRedirect(
      onboardingDone: onboardingDone.value,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        name: AppRouteName.welcome,
        path: AppRoutePath.welcome,
        pageBuilder: (context, state) =>
            const CupertinoPage(child: WelcomePage()),
      ),
      GoRoute(
        name: AppRouteName.setup,
        path: AppRoutePath.setup,
        pageBuilder: (context, state) =>
            const CupertinoPage(child: SetupPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteName.home,
                path: AppRoutePath.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteName.phrases,
                path: AppRoutePath.phrases,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: PhrasesPage(
                    initialTab: state.uri.queryParameters['tab'] == 'quick'
                        ? PhrasesTab.quick
                        : PhrasesTab.mine,
                  ),
                ),
                routes: [
                  GoRoute(
                    name: AppRouteName.situation,
                    path: AppRoutePath.situation,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => CupertinoPage(
                      child: SituationPage(
                        situationKey: state.pathParameters['key']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    name: AppRouteName.review,
                    path: AppRoutePath.review,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: ReviewPage()),
                  ),
                  GoRoute(
                    name: AppRouteName.addPhrase,
                    path: AppRoutePath.addPhrase,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: AddPhrasePage()),
                  ),
                  GoRoute(
                    name: AppRouteName.phrase,
                    path: AppRoutePath.phrase,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => CupertinoPage(
                      child: PhraseDetailPage(
                        phraseId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteName.history,
                path: AppRoutePath.history,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HistoryPage()),
                routes: [
                  GoRoute(
                    name: AppRouteName.transcript,
                    path: AppRoutePath.transcript,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => CupertinoPage(
                      child: TranscriptPage(
                        sessionId: state.pathParameters['id']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        name: AppRouteName.phrasingReview,
                        path: AppRoutePath.phrasingReview,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => CupertinoPage(
                          child: PhrasingReviewPage(
                            sessionId: state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                name: AppRouteName.me,
                path: AppRoutePath.me,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MePage()),
                routes: [
                  GoRoute(
                    name: AppRouteName.translationVoice,
                    path: AppRoutePath.translationVoice,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: TranslationVoicePage()),
                  ),
                  GoRoute(
                    name: AppRouteName.privacy,
                    path: AppRoutePath.privacy,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: PrivacyPage()),
                  ),
                  GoRoute(
                    name: AppRouteName.account,
                    path: AppRoutePath.account,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: AccountPage()),
                  ),
                  GoRoute(
                    name: AppRouteName.glossary,
                    path: AppRoutePath.glossary,
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: GlossaryPage()),
                    routes: [
                      GoRoute(
                        name: AppRouteName.glossarySet,
                        path: AppRoutePath.glossarySet,
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => CupertinoPage(
                          child: GlossarySetPage(
                            setId: state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        name: AppRouteName.signIn,
        path: AppRoutePath.signIn,
        pageBuilder: (context, state) => CupertinoPage(
          fullscreenDialog: true,
          child: SignInPage(
            reason:
                SignInReason.values
                    .where((r) => r.name == state.uri.queryParameters['reason'])
                    .firstOrNull ??
                SignInReason.account,
          ),
        ),
        routes: [
          GoRoute(
            name: AppRouteName.signInEmail,
            path: AppRoutePath.signInEmail,
            pageBuilder: (context, state) =>
                const CupertinoPage(child: EmailSignInPage()),
          ),
        ],
      ),
      GoRoute(
        name: AppRouteName.emailLink,
        path: AppRoutePath.emailLink,
        pageBuilder: (context, state) {
          final extra = state.extra is EmailLinkRequest
              ? state.extra! as EmailLinkRequest
              : const EmailLinkRequest('', EmailLinkOutcome.invalid);
          return CupertinoPage(
            child: EmailLinkPage(link: extra.link, outcome: extra.outcome),
          );
        },
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
      GoRoute(
        name: AppRouteName.listen,
        path: AppRoutePath.listen,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return CupertinoPage(
            child: ListenPage(
              languages: LanguagePair(
                query['from'] ?? 'en',
                query['to'] ?? 'vi',
              ),
            ),
          );
        },
      ),
      GoRoute(
        name: AppRouteName.meeting,
        path: AppRoutePath.meeting,
        pageBuilder: (context, state) =>
            const CupertinoPage(child: MeetingPage()),
      ),
      GoRoute(
        name: AppRouteName.showMode,
        path: AppRoutePath.showMode,
        pageBuilder: (context, state) {
          final extra = state.extra is Map<String, String?>
              ? state.extra! as Map<String, String?>
              : const <String, String?>{};
          return CupertinoPage(
            fullscreenDialog: true,
            child: ShowModePage(
              text: extra['text'] ?? '',
              original: extra['original'],
              lang: extra['lang'],
              hint: extra['hint'],
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
  ref.onDispose(router.dispose);
  return router;
});

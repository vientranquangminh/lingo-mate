import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/common/widgets/app_platform_elevated_button.dart';
import 'package:lingo_mate/core/auth/auth_models.dart';
import 'package:lingo_mate/core/auth/auth_providers.dart';
import 'package:lingo_mate/core/phrases/phrase_repository.dart';
import 'package:lingo_mate/core/platform/system_settings.dart';
import 'package:lingo_mate/core/sync/cloud_store.dart';
import 'package:lingo_mate/core/sync/sync_controller.dart';
import 'package:lingo_mate/flavor_config.dart';
import 'package:lingo_mate/my_app.dart';
import 'package:lingo_mate/navigation/app_routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_fakes.dart';
import '../../core/sync/sync_fakes.dart';
import '../../helpers/fake_platform.dart';
import '../conversation/conversation_fakes.dart';
import '../language_packs/language_packs_fakes.dart';
import '../learning/learning_pages_test.dart' show settle;

void main() {
  late ConversationFakes fakes;
  late FakeAuthService auth;
  late StreamController<Uri> links;
  late FakeCloudStore cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done': true,
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    links = fakes.links;
    auth = FakeAuthService();
    cloud = FakeCloudStore();
    FlavorConfig(appFlavor: Flavor.production);
  });

  tearDown(() => fakes.db.close());

  /// Pumps the app on Home.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        ...packOverrides(
          translation: FakeTranslationModels(),
          speech: FakeSpeechModelFiles(),
          voices: FakeVoiceChecker(),
          wifi: FakeWifiState(),
        ),
        ...fakes.overrides(),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        authServiceProvider.overrideWithValue(auth),
        cloudStoreProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MyApp()),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    });
    return container;
  }

  /// Opens the Me tab.
  Future<void> openMe(WidgetTester tester) async {
    await tester.tap(find.text('Me').last);
    await settle(tester);
  }

  testWidgets(
    'an anonymous user sees the sign-in card, which opens S-24 (AC-13.8, AC-13.2)',
    (tester) async {
      await pumpApp(tester);
      await openMe(tester);

      expect(find.text('Sign in to sync and use Live'), findsOneWidget);
      await tester.tap(find.text('Sign in to sync and use Live'));
      await settle(tester);

      expect(find.text('Sign in to keep everything with you'), findsOneWidget);
      expect(
        find.text(
          'Your account keeps your phrases and plan when you change phones.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('Later, use without an account'), findsOneWidget);
    },
  );

  testWidgets('S-24 names the entry point', (tester) async {
    final container = await pumpApp(tester);
    container.read(goRouterProvider).push('/sign-in?reason=live');
    await settle(tester);

    expect(
      find.text('Live translation needs an account, including the free trial.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Google links the account and the card shows it (AC-13.3, AC-13.7)',
    (tester) async {
      await pumpApp(tester);
      await openMe(tester);
      await tester.tap(find.text('Sign in to sync and use Live'));
      await settle(tester);

      await tester.tap(find.text('Continue with Google'));
      await settle(tester);

      expect(find.text('Sign in to keep everything with you'), findsNothing);
      expect(find.text('Minh Tran'), findsOneWidget);
      expect(find.text('minh@example.com · Google'), findsOneWidget);
      expect(find.text('MT'), findsOneWidget);
    },
  );

  testWidgets('a cancelled Google sign-in stays on S-24', (tester) async {
    auth.googleResult = const SignInResult(SignInOutcome.cancelled);
    final container = await pumpApp(tester);
    container.read(goRouterProvider).push('/sign-in');
    await settle(tester);

    await tester.tap(find.text('Continue with Google'));
    await settle(tester);

    expect(find.text('Sign in to keep everything with you'), findsOneWidget);
  });

  testWidgets('says when Google sign-in is not set up for the build', (
    tester,
  ) async {
    auth.googleResult = const SignInResult(SignInOutcome.notConfigured);
    final container = await pumpApp(tester);
    container.read(goRouterProvider).push('/sign-in');
    await settle(tester);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    expect(
      find.textContaining("Google sign-in isn't set up for this build yet"),
      findsOneWidget,
    );
    expect(find.text('Sign in to keep everything with you'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('email sends a link and finishes when it is opened (AC-13.5)', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container.read(goRouterProvider).push('/sign-in');
    await settle(tester);
    await tester.tap(find.text('Continue with email'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'not-an-email');
    await tester.pump();
    await tester.tap(find.text('Send link'));
    await settle(tester);
    expect(auth.sentTo, isEmpty);

    await tester.enterText(find.byType(TextField), 'minh@example.com');
    await tester.pump();
    await tester.tap(find.text('Send link'));
    await settle(tester);
    expect(auth.sentTo, ['minh@example.com']);
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('Send again'), findsOneWidget);

    auth.setUser(
      const AppUser(
        uid: 'anon',
        provider: AuthProviderKind.email,
        email: 'minh@example.com',
      ),
    );
    await settle(tester);
    expect(find.text('Check your inbox'), findsNothing);
    expect(find.text('Sign in to keep everything with you'), findsNothing);
  });

  testWidgets('a link opened on another phone asks for the email (AC-13.5)', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container
        .read(goRouterProvider)
        .push(
          '/email-link',
          extra: const EmailLinkRequest(
            'https://x/link',
            EmailLinkOutcome.needsEmail,
          ),
        );
    await settle(tester);

    expect(find.textContaining('opened on a different phone'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'minh@example.com');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(auth.confirmedEmail, 'minh@example.com');
    expect(auth.currentUser!.provider, AuthProviderKind.email);
  });

  testWidgets('an opened sign-in link signs in, or asks for the email', (
    tester,
  ) async {
    await pumpApp(tester);

    links.add(
      Uri.parse('https://lingo-mate-4f38d.firebaseapp.com/__/auth/links?x=1'),
    );
    await settle(tester);
    expect(auth.currentUser!.provider, AuthProviderKind.email);

    auth.linkOutcome = EmailLinkOutcome.needsEmail;
    links.add(
      Uri.parse('https://lingo-mate-4f38d.firebaseapp.com/__/auth/links?x=2'),
    );
    await settle(tester);
    expect(find.textContaining('opened on a different phone'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('an expired link offers Send again (AC-13.5)', (tester) async {
    final container = await pumpApp(tester);
    container
        .read(goRouterProvider)
        .push(
          '/email-link',
          extra: const EmailLinkRequest(
            'https://x/link',
            EmailLinkOutcome.invalid,
          ),
        );
    await settle(tester);

    expect(
      find.text('This sign-in link is invalid or has expired.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send again'));
    await settle(tester);
    expect(find.text('Send link'), findsOneWidget);
  });

  testWidgets('sign out can remove this phone\'s data (AC-13.11)', (
    tester,
  ) async {
    auth = FakeAuthService(
      user: const AppUser(
        uid: 'u1',
        provider: AuthProviderKind.google,
        displayName: 'Minh Tran',
        email: 'minh@example.com',
      ),
    );
    await tester.runAsync(
      () => PhraseRepository(fakes.db).save(
        sourceLang: 'vi',
        sourceText: 'Cảm ơn',
        targetLang: 'en',
        targetText: 'Thank you',
      ),
    );
    await pumpApp(tester);
    await openMe(tester);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Minh Tran'));
    await settle(tester);
    await tester.tap(find.text('Sign out'));
    await settle(tester);
    await tester.tap(find.text("Remove this phone's data"));
    await settle(tester);

    expect(auth.signOuts, 1);
    final left = await tester.runAsync(
      () => PhraseRepository(fakes.db).watchCount().first,
    );
    expect(left, 0);
    expect(find.text('Sign in to sync and use Live'), findsOneWidget);
  });

  testWidgets('the account page renames the user', (tester) async {
    auth = FakeAuthService(
      user: const AppUser(
        uid: 'u1',
        provider: AuthProviderKind.email,
        email: 'minh@example.com',
      ),
    );
    await pumpApp(tester);
    await openMe(tester);
    await tester.tap(find.text('minh@example.com').first);
    await settle(tester);

    await tester.tap(find.text('Name'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Minh');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(auth.currentUser!.displayName, 'Minh');
    expect(find.text('Email link'), findsOneWidget);
  });

  testWidgets(
    'turning sync on asks to sign in, then uploads the phrasebook (AC-13.9)',
    (tester) async {
      await tester.runAsync(
        () => PhraseRepository(fakes.db).save(
          sourceLang: 'vi',
          sourceText: 'Cảm ơn',
          targetLang: 'en',
          targetText: 'Thank you',
        ),
      );
      final container = await pumpApp(tester);
      container.read(goRouterProvider).push('/me/privacy');
      await settle(tester);

      await tester.tap(find.text('Sync phrasebook and review'));
      await settle(tester);
      expect(
        find.text('Sign in to sync your phrasebook and review schedule.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue with Google'));
      await settle(tester);
      await settle(tester);

      expect(container.read(syncControllerProvider).active, isTrue);
      expect(cloud.docs('anon', CloudCollection.phrases), hasLength(1));
      expect(cloud.profiles['anon']!['email'], 'minh@example.com');
      await tester.runAsync(
        () => container.read(syncControllerProvider.notifier).setEnabled(false),
      );
      await settle(tester);
    },
  );

  testWidgets(
    'signing in to an existing account can replace this phone\'s phrases (AC-13.4)',
    (tester) async {
      auth.googleResult = const SignInResult(SignInOutcome.switchedAccount);
      await tester.runAsync(
        () => PhraseRepository(fakes.db).save(
          sourceLang: 'vi',
          sourceText: 'Cảm ơn',
          targetLang: 'en',
          targetText: 'Thank you',
        ),
      );
      final container = await pumpApp(tester);
      container.read(goRouterProvider).push('/sign-in');
      await settle(tester);

      await tester.tap(find.text('Continue with Google'));
      await settle(tester);
      expect(
        find.text("Add this phone's phrases to your account?"),
        findsOneWidget,
      );
      await tester.tap(find.text("Don't merge"));
      await settle(tester);

      final left = await tester.runAsync(
        () => PhraseRepository(fakes.db).watchCount().first,
      );
      expect(left, 0);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  /// Taps Delete account and confirms it in the dialog.
  Future<void> tapDelete(WidgetTester tester) async {
    final button = find.widgetWithText(
      AppPlatformElevatedButton,
      'Delete account',
    );
    await tester.ensureVisible(button);
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
    expect(find.text('Delete your account?'), findsOneWidget);
    await tester.tap(find.text('Delete account').last);
    await settle(tester);
  }

  /// Opens the delete page as the signed-in [user].
  Future<void> openDelete(WidgetTester tester, AppUser user) async {
    auth = FakeAuthService(user: user);
    final container = await pumpApp(tester);
    container.read(goRouterProvider).push('/me/account/delete');
    await settle(tester);
  }

  const google = AppUser(
    uid: 'u1',
    provider: AuthProviderKind.google,
    displayName: 'Minh Tran',
    email: 'minh@example.com',
  );

  testWidgets(
    'delete account signs in again, deletes and restarts onboarding (AC-13.12, AC-13.13)',
    (tester) async {
      await openDelete(tester, google);
      expect(
        find.textContaining('not cancelled by deleting your account'),
        findsOneWidget,
      );
      expect(find.text('Open Google Play subscriptions'), findsOneWidget);

      await tapDelete(tester);

      expect(auth.reauths, 1);
      expect(auth.deletions, 1);
      expect(fakes.prefs.getBool('onboarding_done'), isNull);
      expect(find.text('Talk to anyone.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets('a cancelled sign-in keeps the account', (tester) async {
    await openDelete(tester, google);
    auth.reauthResult = const SignInResult(SignInOutcome.cancelled);

    await tapDelete(tester);

    expect(auth.deletions, 0);
    expect(find.text('Delete account'), findsWidgets);
  });

  testWidgets(
    'an email account confirms with a new link when the login is old',
    (tester) async {
      await openDelete(
        tester,
        const AppUser(
          uid: 'u1',
          provider: AuthProviderKind.email,
          email: 'minh@example.com',
        ),
      );
      auth.deletion = AccountDeletion.needsRecentLogin;

      await tapDelete(tester);

      expect(auth.sentTo, ['minh@example.com']);
      expect(
        find.textContaining('open the link we sent to minh@example.com'),
        findsOneWidget,
      );
    },
  );
}

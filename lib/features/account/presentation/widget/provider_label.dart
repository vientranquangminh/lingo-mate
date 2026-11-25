import '../../../../core/auth/auth_models.dart';
import '../../../../generated/l10n.dart';

/// The name of a sign-in provider.
abstract final class ProviderLabel {
  /// Returns the label of [provider].
  static String of(AppLocalizations l10n, AuthProviderKind provider) =>
      switch (provider) {
        AuthProviderKind.google => l10n.accountProviderGoogle,
        AuthProviderKind.email => l10n.accountProviderEmail,
        AuthProviderKind.anonymous => l10n.accountProviderNone,
      };
}

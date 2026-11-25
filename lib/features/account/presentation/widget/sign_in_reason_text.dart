import '../../../../core/auth/auth_models.dart';
import '../../../../generated/l10n.dart';

/// The one-line reason S-24 gives for each entry point (AC-13.2).
abstract final class SignInReasonText {
  /// Returns the line for [reason].
  static String of(AppLocalizations l10n, SignInReason reason) =>
      switch (reason) {
        SignInReason.account => l10n.signInReasonAccount,
        SignInReason.sync => l10n.signInReasonSync,
        SignInReason.live => l10n.signInReasonLive,
        SignInReason.purchase => l10n.signInReasonPurchase,
        SignInReason.restore => l10n.signInReasonRestore,
      };
}

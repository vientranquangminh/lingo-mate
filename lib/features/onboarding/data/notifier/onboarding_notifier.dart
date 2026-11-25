import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/engines/selection/capability_matrix.dart';
import '../../../../core/settings/user_settings.dart';
import '../../../language_packs/data/model/pack_models.dart';
import '../../../language_packs/data/notifier/language_packs_notifier.dart';
import '../state/onboarding_state.dart';

/// The phone's language code.
final deviceLanguageProvider = Provider<String>(
  (ref) => PlatformDispatcher.instance.locale.languageCode,
);

/// Setup in progress; starts from saved choices when setup runs again.
final onboardingProvider =
    NotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );

/// Walks through "I speak", "I talk with" and the pack offer, then saves the choices (F-01).
class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final settings = ref.read(userSettingsProvider);
    return OnboardingState(
      mine: settings.myLanguage ?? ref.read(deviceLanguageProvider),
      partners: settings.partnerLanguages,
    );
  }

  /// Keeps the preselected language only when the matrix has it, else English (AC-01.2).
  void fitTo(CapabilityMatrix matrix) {
    if (!matrix.languages.containsKey(state.mine)) {
      state = state.copyWith(mine: 'en');
    }
  }

  /// Chooses the user's own language.
  void selectMine(String lang) => state = state.copyWith(
    mine: lang,
    partners: state.partners.where((l) => l != lang).toList(),
  );

  /// Adds or removes a partner language.
  void togglePartner(String lang) => state = state.copyWith(
    partners: state.partners.contains(lang)
        ? state.partners.where((l) => l != lang).toList()
        : [...state.partners, lang],
  );

  /// Moves to the next step when allowed.
  void next() {
    if (!state.canContinue || state.step == SetupStep.packs) {
      return;
    }
    state = state.copyWith(step: SetupStep.values[state.step.index + 1]);
  }

  /// Moves to the previous step; returns false on the first one.
  bool back() {
    if (state.step == SetupStep.iSpeak) {
      return false;
    }
    state = state.copyWith(step: SetupStep.values[state.step.index - 1]);
    return true;
  }

  /// Saves the languages, starts pack downloads when [download], and ends setup (AC-01.4, AC-01.5).
  Future<void> finish({required bool download}) async {
    final settings = ref.read(userSettingsProvider.notifier);
    await settings.setLanguages(mine: state.mine, partners: state.partners);
    if (download) {
      final packs = ref.read(languagePacksProvider.notifier);
      for (final lang in state.allLanguages) {
        final pack = ref.read(languagePacksProvider).pack(lang);
        if (pack != null && pack.status == PackStatus.notDownloaded) {
          unawaited(packs.download(lang));
        }
      }
    }
    await settings.setOnboardingDone(true);
  }
}

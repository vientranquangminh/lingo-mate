import 'package:equatable/equatable.dart';

/// The steps after Welcome (S-02 and the pack offer).
enum SetupStep { iSpeak, talkWith, packs }

/// Choices made during setup.
class OnboardingState extends Equatable {
  const OnboardingState({
    this.step = SetupStep.iSpeak,
    required this.mine,
    this.partners = const [],
  });

  final SetupStep step;
  final String mine;
  final List<String> partners;

  /// Whether Continue may be pressed on the current step (AC-01.3: at least one partner language).
  bool get canContinue => step != SetupStep.talkWith || partners.isNotEmpty;

  /// Own language first, then partner languages, without repeats.
  List<String> get allLanguages => [mine, ...partners.where((l) => l != mine)];

  OnboardingState copyWith({
    SetupStep? step,
    String? mine,
    List<String>? partners,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      mine: mine ?? this.mine,
      partners: partners ?? this.partners,
    );
  }

  @override
  List<Object?> get props => [step, mine, partners];
}

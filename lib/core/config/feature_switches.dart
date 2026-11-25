import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/selection/engine_providers.dart';
import 'remote_config_service.dart';

/// Remote Config switches for the features that cost money, so the owner can turn one off at once.
class FeatureSwitches extends Equatable {
  const FeatureSwitches({
    this.standard = true,
    this.summary = true,
    this.suggestReply = true,
    this.glossary = true,
    this.postSessionReview = false,
  });

  /// Reads the switches from [config].
  factory FeatureSwitches.from(RemoteConfigService config) => FeatureSwitches(
    standard: config.standardEnabled,
    summary: config.summaryEnabled,
    suggestReply: config.suggestReplyEnabled,
    glossary: config.glossaryEnabled,
    postSessionReview: config.postSessionReviewEnabled,
  );

  final bool standard;
  final bool summary;
  final bool suggestReply;
  final bool glossary;
  final bool postSessionReview;

  @override
  List<Object?> get props => [
    standard,
    summary,
    suggestReply,
    glossary,
    postSessionReview,
  ];
}

/// The current switches; rebuilt when Remote Config publishes new values.
final featureSwitchesProvider = Provider<FeatureSwitches>((ref) {
  final config = ref.watch(engineRemoteConfigProvider);
  final updates = config.updates.listen((_) => ref.invalidateSelf());
  ref.onDispose(updates.cancel);
  return FeatureSwitches.from(config);
});

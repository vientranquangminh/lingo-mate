import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/learning/learning_assistant.dart';
import '../../../../core/learning/learning_models.dart';
import '../../../../core/sessions/session_repository.dart';

/// A phrasing tip with the languages it is saved in.
class PhrasingReviewItem {
  const PhrasingReviewItem({
    required this.tip,
    required this.userLang,
    required this.partnerLang,
  });

  final PhrasingTip tip;
  final String userLang;
  final String partnerLang;
}

/// The post-session review of one session, asked once when the screen opens (F-17).
final phrasingReviewProvider = FutureProvider.autoDispose
    .family<List<PhrasingReviewItem>, String>((ref, sessionId) async {
      final detail = await ref.read(sessionRepositoryProvider).load(sessionId);
      if (detail == null) {
        return const [];
      }
      final mine = LearningRules.userLines(detail.utterances);
      if (mine.isEmpty) {
        return const [];
      }
      final userLang = mine.first.sourceLang;
      final partnerLang = mine.first.targetLang;
      final tips = await ref
          .read(learningAssistantProvider)
          .reviewPhrasing(
            lines: [for (final u in mine) LearningLine.fromUtterance(u)],
            userLang: userLang,
            partnerLang: partnerLang,
          );
      return [
        for (final tip in tips)
          PhrasingReviewItem(
            tip: tip,
            userLang: userLang,
            partnerLang: partnerLang,
          ),
      ];
    });

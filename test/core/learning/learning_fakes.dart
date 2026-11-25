import 'dart:async';

import 'package:lingo_mate/core/learning/learning_assistant.dart';
import 'package:lingo_mate/core/learning/learning_models.dart';

/// Scripted [LearningAssistant] that records what it was asked.
class FakeLearningAssistant implements LearningAssistant {
  List<PhrasingTip> tips = const [
    PhrasingTip(
      original: 'Tôi muốn hoá đơn',
      improved: 'Could we have the bill, please?',
      reason: 'Lịch sự và tự nhiên hơn.',
    ),
  ];
  List<SuggestedReply> replies = const [
    SuggestedReply(text: 'Sounds good to me.', backTranslation: 'Nghe ổn đó.'),
    SuggestedReply(
      text: 'Could you say that again?',
      backTranslation: 'Bạn nói lại được không?',
    ),
    SuggestedReply(
      text: 'Thank you so much.',
      backTranslation: 'Cảm ơn nhiều.',
    ),
  ];
  SessionRecap recap = const SessionRecap(
    lang: 'vi',
    summary: 'Nhóm thống nhất giao bản thử vào thứ Sáu.',
    keyTerms: ['webhook'],
    actionItems: ['Minh gửi bản thử trước thứ Sáu'],
  );
  Object? error;
  final List<List<LearningLine>> asked = [];
  String? lastReplyLang;
  String? lastSummaryLang;

  @override
  Future<List<PhrasingTip>> reviewPhrasing({
    required List<LearningLine> lines,
    required String userLang,
    required String partnerLang,
  }) async {
    asked.add(lines);
    _throwIfFailing();
    return tips;
  }

  @override
  Future<List<SuggestedReply>> suggestReplies({
    required List<LearningLine> recent,
    required String replyLang,
    required String userLang,
  }) async {
    asked.add(recent);
    lastReplyLang = replyLang;
    _throwIfFailing();
    return replies;
  }

  @override
  Future<SessionRecap> summarize({
    required List<LearningLine> lines,
    required String userLang,
  }) async {
    asked.add(lines);
    lastSummaryLang = userLang;
    _throwIfFailing();
    return recap;
  }

  /// Throws [error] when set.
  void _throwIfFailing() {
    final e = error;
    if (e != null) {
      throw e;
    }
  }
}

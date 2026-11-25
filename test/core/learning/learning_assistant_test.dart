import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/learning/learning_assistant.dart';
import 'package:lingo_mate/core/learning/learning_models.dart';

void main() {
  const lines = [
    LearningLine(
      speaker: 'a',
      sourceLang: 'vi',
      sourceText: 'Tôi muốn hoá đơn',
      targetLang: 'en',
      targetText: 'I want bill',
    ),
  ];

  /// An assistant that answers [answer] and keeps the prompts it got.
  (GeminiLearningAssistant, List<String>) assistant(String answer) {
    final prompts = <String>[];
    return (
      GeminiLearningAssistant(({required system, required user}) async {
        prompts
          ..add(system)
          ..add(user);
        return answer;
      }),
      prompts,
    );
  }

  test('the review keeps at most five tips with original, improved and reason (AC-17.1)', () async {
    final items = List.generate(
      7,
      (i) => '{"original":"o$i","improved":"i$i","reason":"r$i"}',
    ).join(',');
    final (gemini, prompts) = assistant('```json\n{"items":[$items]}\n```');

    final tips = await gemini.reviewPhrasing(
      lines: lines,
      userLang: 'vi',
      partnerLang: 'en',
    );

    expect(tips, hasLength(5));
    expect(
      tips.first,
      const PhrasingTip(original: 'o0', improved: 'i0', reason: 'r0'),
    );
    expect(prompts.first, contains('at most 5'));
    expect(prompts.last, contains('Tôi muốn hoá đơn => I want bill'));
  });

  test(
    'suggested replies come with back-translations, three at most (AC-19.1)',
    () async {
      final (gemini, prompts) = assistant(
        '{"replies":[{"text":"Yes","back":"Vâng"},{"text":"No","back":"Không"},'
        '{"text":"Maybe","back":"Có lẽ"},{"text":"Extra","back":"Thêm"}]}',
      );
      final recent = List.generate(
        8,
        (i) => LearningLine(
          sourceLang: 'vi',
          sourceText: 'câu $i',
          targetLang: 'en',
          targetText: 'line $i',
        ),
      );

      final replies = await gemini.suggestReplies(
        recent: recent,
        replyLang: 'en',
        userLang: 'vi',
      );

      expect(replies, hasLength(3));
      expect(
        replies.first,
        const SuggestedReply(text: 'Yes', backTranslation: 'Vâng'),
      );
      expect(prompts.last, isNot(contains('câu 2')));
      expect(prompts.last, contains('câu 3'));
    },
  );

  test(
    'a summary keeps key terms and action items and survives storage (AC-20.1)',
    () async {
      final (gemini, _) = assistant(
        '{"summary":"S","keyTerms":["a",""],"actionItems":["do it"]}',
      );

      final recap = await gemini.summarize(lines: lines, userLang: 'vi');

      expect(recap.summary, 'S');
      expect(recap.keyTerms, ['a']);
      expect(recap.actionItems, ['do it']);
      expect(SessionRecap.decode(recap.encode()), recap);
      expect(SessionRecap.decode('not json'), isNull);
    },
  );

  test('an answer without JSON is an error', () async {
    final (gemini, _) = assistant('Sorry, I cannot help.');

    expect(
      () => gemini.summarize(lines: lines, userLang: 'vi'),
      throwsFormatException,
    );
  });

  test('summary text lists the terms and action items (AC-20.2)', () {
    const recap = SessionRecap(
      lang: 'en',
      summary: 'We agreed.',
      keyTerms: ['webhook'],
      actionItems: ['Ship Friday'],
    );

    expect(
      LearningRules.summaryText(
        recap,
        title: 'Sync',
        keyTermsLabel: 'Key terms',
        actionItemsLabel: 'Action items',
      ),
      'Sync\n\nWe agreed.\n\nKey terms\n• webhook\n\nAction items\n• Ship Friday',
    );
  });

  test('summaries need a Meeting or Listen session of 3 minutes', () {
    expect(LearningRules.canSummarize('meeting', 180), isTrue);
    expect(LearningRules.canSummarize('listen', 179), isFalse);
    expect(LearningRules.canSummarize('conversation', 600), isFalse);
  });
}

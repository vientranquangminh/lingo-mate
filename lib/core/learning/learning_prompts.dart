import 'learning_models.dart';

/// Builds the Gemini prompts of the learning features; each asks for JSON only.
abstract final class LearningPrompts {
  static const maxTips = 5;
  static const replyContext = 5;

  /// System instruction for the post-session review (F-17).
  static String reviewSystem({
    required String userLang,
    required String partnerLang,
  }) =>
      'You are a friendly language coach. The user speaks $userLang and talks '
      'with people who speak $partnerLang. Each line shows what the user said '
      'and the machine translation into $partnerLang. Pick at most $maxTips '
      'lines whose $partnerLang could sound more natural and, for each, write '
      'how a native $partnerLang speaker would say it and one short reason in '
      '$userLang. Skip lines that are already natural. Answer with JSON only: '
      '{"items":[{"original":"<what the user said, copied exactly>",'
      '"improved":"<natural $partnerLang>","reason":"<one line in $userLang>"}]}';

  /// System instruction for suggested replies (F-19).
  static String repliesSystem({
    required String replyLang,
    required String userLang,
  }) =>
      'You help the user reply in a live conversation. Based on the recent '
      'lines, write exactly 3 short, polite, different replies the user could '
      'say next, in $replyLang, each with a back-translation into $userLang. '
      'Answer with JSON only: {"replies":[{"text":"<reply in $replyLang>",'
      '"back":"<back-translation in $userLang>"}]}';

  /// System instruction for the session summary (F-20).
  static String summarySystem({required String userLang}) =>
      'You summarise a transcript of a meeting or talk for the user. Write in '
      '$userLang: a summary of 3 to 6 sentences, up to 8 key terms (keep each '
      'term in the language it was spoken, with a short gloss in $userLang '
      'when it is not $userLang), and the action items with who and when when '
      'said (empty when there are none). Answer with JSON only: '
      '{"summary":"...","keyTerms":["..."],"actionItems":["..."]}';

  /// One numbered line per transcript line: speaker, original and translation.
  static String transcript(List<LearningLine> lines) {
    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final who = line.speaker == null ? '' : '[${line.speaker}] ';
      buffer.writeln(
        '${i + 1}. $who${_oneLine(line.sourceText)} '
        '=> ${_oneLine(line.targetText)}',
      );
    }
    return buffer.toString().trim();
  }

  /// Collapses line breaks so one item stays on one line.
  static String _oneLine(String value) =>
      value.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
}

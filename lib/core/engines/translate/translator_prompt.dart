/// Builds the Gemini translation prompt (doc 04 §3).
abstract final class TranslatorPrompt {
  static const contextSize = 3;

  /// Returns the system instruction for translating [from] into [to].
  static String system({required String from, required String to}) =>
      "You are a professional interpreter. Translate the user's utterance "
      'from $from to $to. Output only the translation. Keep names, numbers, '
      'units and code identifiers unchanged. Match the speaker\'s register. '
      'Use the glossary when a term appears. If the input is not in $from, '
      'translate it to $to anyway.';

  /// Returns the user message: the last [contextSize] utterances, glossary terms and the text to translate.
  static String user({
    required String text,
    List<String> context = const [],
    Map<String, String> glossary = const {},
  }) {
    final recent = context.length > contextSize
        ? context.sublist(context.length - contextSize)
        : context;
    final buffer = StringBuffer();
    if (recent.isNotEmpty) {
      buffer.writeln('Previous utterances (context only, do not translate):');
      for (final line in recent) {
        buffer.writeln('- ${_oneLine(line)}');
      }
    }
    if (glossary.isNotEmpty) {
      buffer.writeln('Glossary:');
      glossary.forEach((term, translation) {
        buffer.writeln('- ${_oneLine(term)} = ${_oneLine(translation)}');
      });
    }
    if (buffer.isNotEmpty) {
      buffer.writeln('Translate:');
    }
    buffer.write(text.trim());
    return buffer.toString();
  }

  /// Collapses line breaks so one item stays on one line.
  static String _oneLine(String value) =>
      value.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
}

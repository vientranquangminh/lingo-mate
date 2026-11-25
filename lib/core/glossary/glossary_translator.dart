import '../engines/engines.dart';

/// Adds the active glossary's matching terms to every request before [inner] translates it (F-18).
class GlossaryTranslator implements TextTranslatorEngine {
  GlossaryTranslator(this._inner, this._termsIn);

  final TextTranslatorEngine _inner;
  final Future<Map<String, String>> Function(String text) _termsIn;

  @override
  String get id => _inner.id;

  @override
  EngineKind get kind => _inner.kind;

  @override
  Future<bool> isAvailable(String from, String to) =>
      _inner.isAvailable(from, to);

  @override
  Future<Translation> translate(TranslateRequest request) async {
    Map<String, String> terms;
    try {
      terms = await _termsIn(request.text);
    } on Object {
      terms = const {};
    }
    return _inner.translate(
      terms.isEmpty ? request : request.withGlossary(terms),
    );
  }
}

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../engines.dart';

/// Offline engine translator: ML Kit on-device models, pivoting through English (doc 04 §5).
class MlKitTextTranslator implements TextTranslatorEngine {
  MlKitTextTranslator({OnDeviceTranslatorModelManager? modelManager})
    : _models = modelManager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _models;
  final _translators = <String, OnDeviceTranslator>{};

  @override
  String get id => 'mlkit';

  @override
  EngineKind get kind => EngineKind.offline;

  /// Returns the ML Kit language for a BCP-47 code, or null when ML Kit has none.
  static TranslateLanguage? languageFor(String code) =>
      BCP47Code.fromRawValue(code.split(RegExp('[-_]')).first.toLowerCase());

  @override
  Future<bool> isAvailable(String from, String to) async {
    final source = languageFor(from);
    final target = languageFor(to);
    if (source == null || target == null || source == target) {
      return false;
    }
    return await _models.isModelDownloaded(source.bcpCode) &&
        await _models.isModelDownloaded(target.bcpCode);
  }

  /// Downloads the models for both languages; Wi-Fi only unless [allowMobileData].
  Future<bool> downloadModels(
    String from,
    String to, {
    bool allowMobileData = false,
  }) async {
    var ok = true;
    for (final code in {from, to}) {
      final language = languageFor(code);
      if (language == null) {
        return false;
      }
      if (!await _models.isModelDownloaded(language.bcpCode)) {
        ok &= await _models.downloadModel(
          language.bcpCode,
          isWifiRequired: !allowMobileData,
        );
      }
    }
    return ok;
  }

  @override
  Future<Translation> translate(TranslateRequest request) async {
    final source = languageFor(request.from);
    final target = languageFor(request.to);
    if (source == null || target == null) {
      throw UnsupportedError(
        'ML Kit cannot translate ${request.from} to ${request.to}',
      );
    }
    final translator = _translators.putIfAbsent(
      '${source.bcpCode}>${target.bcpCode}',
      () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target),
    );
    final text = await translator.translateText(request.text);
    return Translation(text: text.trim(), engine: kind);
  }

  /// Closes every open translator; call when the session ends.
  Future<void> close() async {
    for (final t in _translators.values) {
      await t.close();
    }
    _translators.clear();
  }
}

import 'package:firebase_ai/firebase_ai.dart';
import 'package:injectable/injectable.dart';

import '../config/remote_config_service.dart';

/// Creates Gemini models through Firebase AI Logic with the Remote Config model names.
@lazySingleton
class GenerativeModelFactory {
  GenerativeModelFactory(this._remoteConfig);

  final RemoteConfigService _remoteConfig;

  /// Returns the text model used by the Standard engine to translate.
  GenerativeModel translationModel({required String systemInstruction}) =>
      FirebaseAI.googleAI().generativeModel(
        model: _remoteConfig.modelTextTranslate,
        systemInstruction: Content.system(systemInstruction),
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 256,
        ),
      );

  /// Returns the review model used by the learning features, answering in JSON.
  GenerativeModel reviewModel({required String systemInstruction}) =>
      FirebaseAI.googleAI().generativeModel(
        model: _remoteConfig.modelTextReview,
        systemInstruction: Content.system(systemInstruction),
        generationConfig: GenerationConfig(
          temperature: 0.4,
          maxOutputTokens: 1024,
          responseMimeType: 'application/json',
        ),
      );
}

/// Values passed at build time with `--dart-define-from-file=.env.<flavor>`.
class Env {
  static String get restApiEndpoint =>
      const String.fromEnvironment('REST_API_ENDPOINT');

  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_API_KEY');

  static bool get liveEnabled =>
      const bool.fromEnvironment('LIVE_ENABLED', defaultValue: false);

  static String get appCheckDebugToken =>
      const String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
}

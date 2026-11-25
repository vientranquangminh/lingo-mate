abstract class AppRouteName {
  static const onboarding = 'onboarding';
  static const devtools = 'devtools';
  static const languagePacks = 'language-packs';
  static const conversation = 'conversation';
  static const showMode = 'show';
  static const history = 'history';
  static const transcript = 'transcript';
}

abstract class AppRoutePath {
  static const onboarding = '/';
  static const devtools = '/devtools';
  static const languagePacks = '/language-packs';
  static const conversation = '/conversation';
  static const showMode = '/show';
  static const history = '/history';
  static const transcript = ':id';
}

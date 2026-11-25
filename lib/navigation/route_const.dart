abstract class AppRouteName {
  static const welcome = 'welcome';
  static const setup = 'setup';
  static const home = 'home';
  static const phrases = 'phrases';
  static const me = 'me';
  static const devtools = 'devtools';
  static const languagePacks = 'language-packs';
  static const conversation = 'conversation';
  static const showMode = 'show';
  static const history = 'history';
  static const transcript = 'transcript';
}

abstract class AppRoutePath {
  static const welcome = '/welcome';
  static const setup = '/setup';
  static const home = '/';
  static const phrases = '/phrases';
  static const me = '/me';
  static const devtools = '/devtools';
  static const languagePacks = '/language-packs';
  static const conversation = '/conversation';
  static const showMode = '/show';
  static const history = '/history';
  static const transcript = ':id';
}

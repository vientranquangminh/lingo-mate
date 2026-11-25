abstract class AppRouteName {
  static const welcome = 'welcome';
  static const setup = 'setup';
  static const home = 'home';
  static const phrases = 'phrases';
  static const me = 'me';
  static const devtools = 'devtools';
  static const languagePacks = 'language-packs';
  static const conversation = 'conversation';
  static const listen = 'listen';
  static const meeting = 'meeting';
  static const showMode = 'show';
  static const history = 'history';
  static const transcript = 'transcript';
  static const phrase = 'phrase';
  static const addPhrase = 'add-phrase';
  static const review = 'review';
  static const situation = 'situation';
  static const translationVoice = 'translation-voice';
  static const privacy = 'privacy';
  static const phrasingReview = 'phrasing-review';
  static const glossary = 'glossary';
  static const glossarySet = 'glossary-set';
  static const signIn = 'sign-in';
  static const signInEmail = 'sign-in-email';
  static const emailLink = 'email-link';
  static const account = 'account';
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
  static const listen = '/listen';
  static const meeting = '/meeting';
  static const showMode = '/show';
  static const history = '/history';
  static const transcript = ':id';
  static const phrase = ':id';
  static const addPhrase = 'new';
  static const review = 'review';
  static const situation = 'quick/:key';
  static const translationVoice = 'translation';
  static const privacy = 'privacy';
  static const phrasingReview = 'review';
  static const glossary = 'glossary';
  static const glossarySet = ':id';
  static const signIn = '/sign-in';
  static const signInEmail = 'email';
  static const emailLink = '/email-link';
  static const account = 'account';
}

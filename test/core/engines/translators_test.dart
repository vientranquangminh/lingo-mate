import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/translate/gemini_text_translator.dart';
import 'package:lingo_mate/core/engines/translate/mlkit_text_translator.dart';
import 'package:lingo_mate/core/engines/translate/translator_prompt.dart';

void main() {
  group('TranslatorPrompt', () {
    test('names both languages in the system instruction', () {
      final system = TranslatorPrompt.system(from: 'vi', to: 'en');

      expect(system, contains('from vi to en'));
      expect(system, contains('Output only the translation'));
    });

    test('keeps only the last 3 utterances as context', () {
      final user = TranslatorPrompt.user(
        text: 'Cảm ơn',
        context: ['one', 'two', 'three', 'four'],
      );

      expect(user, isNot(contains('- one')));
      expect(user, contains('- two\n- three\n- four'));
      expect(user, endsWith('Translate:\nCảm ơn'));
    });

    test('adds glossary terms and keeps each item on one line', () {
      final user = TranslatorPrompt.user(
        text: 'xin chào',
        context: ['line one\nline two'],
        glossary: {'API': 'giao diện lập trình'},
      );

      expect(user, contains('- line one line two'));
      expect(user, contains('Glossary:\n- API = giao diện lập trình'));
    });

    test('sends only the text when there is no context', () {
      expect(TranslatorPrompt.user(text: '  hello  '), 'hello');
    });
  });

  group('GeminiTextTranslator', () {
    const request = TranslateRequest(
      from: 'vi',
      to: 'en',
      text: 'Xin chào',
      context: ['a', 'b'],
    );

    test('returns the trimmed translation with the prompt', () async {
      String? sentSystem;
      String? sentUser;
      final translator = GeminiTextTranslator(({
        required system,
        required user,
      }) async {
        sentSystem = system;
        sentUser = user;
        return '  Hello  ';
      });

      final result = await translator.translate(request);

      expect(
        result,
        const Translation(text: 'Hello', engine: EngineKind.standard),
      );
      expect(sentSystem, contains('from vi to en'));
      expect(sentUser, endsWith('Translate:\nXin chào'));
    });

    test('retries once after a failure', () async {
      var calls = 0;
      final translator = GeminiTextTranslator(({
        required system,
        required user,
      }) async {
        calls++;
        if (calls == 1) {
          throw StateError('503');
        }
        return 'Hello';
      });

      expect((await translator.translate(request)).text, 'Hello');
      expect(calls, 2);
    });

    test('times out after 6 s and gives up after the retry', () {
      fakeAsync((async) {
        var calls = 0;
        Object? error;
        GeminiTextTranslator(({required system, required user}) {
          calls++;
          return Completer<String?>().future;
        }).translate(request).catchError((Object e) {
          error = e;
          return const Translation(text: '', engine: EngineKind.standard);
        });

        async.elapse(const Duration(seconds: 6));
        expect(calls, 2);
        async.elapse(const Duration(seconds: 6));

        expect(error, isA<TimeoutException>());
      });
    });

    test('fails on an empty answer twice', () async {
      final translator = GeminiTextTranslator(
        ({required system, required user}) async => '   ',
      );

      expect(() => translator.translate(request), throwsStateError);
    });

    test('recognises the region-block error', () {
      expect(
        GeminiTextTranslator.isRegionBlocked(
          Exception('FAILED_PRECONDITION: User location is not supported'),
        ),
        isTrue,
      );
      expect(GeminiTextTranslator.isRegionBlocked(Exception('503')), isFalse);
    });

    test('is not available for the same language', () async {
      final translator = GeminiTextTranslator(
        ({required system, required user}) async => '',
      );

      expect(await translator.isAvailable('vi', 'vi'), isFalse);
      expect(await translator.isAvailable('vi', 'en'), isTrue);
    });
  });

  group('MlKitTextTranslator', () {
    test('maps BCP-47 codes to ML Kit languages', () {
      expect(
        MlKitTextTranslator.languageFor('vi'),
        TranslateLanguage.vietnamese,
      );
      expect(
        MlKitTextTranslator.languageFor('en-US'),
        TranslateLanguage.english,
      );
      expect(MlKitTextTranslator.languageFor('ja'), TranslateLanguage.japanese);
      expect(MlKitTextTranslator.languageFor('km'), isNull);
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/translate/gemini_text_translator.dart';
import 'package:lingo_mate/core/glossary/glossary_repository.dart';
import 'package:lingo_mate/core/glossary/glossary_translator.dart';

void main() {
  late AppDatabase db;
  late GlossaryRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = GlossaryRepository(db);
  });

  tearDown(() => db.close());

  test(
    'sets list their term counts; only one set is active (AC-18.1)',
    () async {
      final client = await repo.createSet('Client A');
      final travel = await repo.createSet('Travel');
      await repo.addTerm(client, term: 'deploy', translation: 'triển khai');
      await repo.addTerm(client, term: 'ticket', translation: 'phiếu');

      await repo.setActive(client, true);
      await repo.setActive(travel, true);

      final sets = await repo.watchSets().first;
      expect(sets.map((s) => s.set.name), ['Client A', 'Travel']);
      expect(sets.first.termCount, 2);
      expect(sets.map((s) => s.set.active), [false, true]);
    },
  );

  test(
    'only the active set supplies terms, matched on whole words either way',
    () async {
      final client = await repo.createSet('Client A');
      await repo.addTerm(client, term: 'deploy', translation: 'triển khai');
      await repo.addTerm(client, term: 'PR', translation: 'yêu cầu hợp nhất');
      await repo.addTerm(client, term: '締め切り', translation: 'hạn chót');

      expect(await repo.termsIn('We deploy on Friday'), isEmpty);

      await repo.setActive(client, true);

      expect(await repo.termsIn('We deploy on Friday'), {
        'deploy': 'triển khai',
      });
      expect(await repo.termsIn('We are redeploying'), isEmpty);
      expect(await repo.termsIn('Ai review PR này?'), {
        'PR': 'yêu cầu hợp nhất',
      });
      expect(await repo.termsIn('Khi nào triển khai?'), {
        'triển khai': 'deploy',
      });
      expect(await repo.termsIn('締め切りは金曜日です'), {'締め切り': 'hạn chót'});
    },
  );

  test('deleting a set deletes its terms', () async {
    final id = await repo.createSet('Client A');
    await repo.addTerm(id, term: 'deploy', translation: 'triển khai');

    await repo.deleteSet(id);

    expect(await db.select(db.glossaryTerms).get(), isEmpty);
  });

  test(
    'Standard translations get the matching terms in the prompt (F-18)',
    () async {
      final id = await repo.createSet('Client A');
      await repo.addTerm(id, term: 'deploy', translation: 'triển khai');
      await repo.setActive(id, true);
      String? prompt;
      final translator = GlossaryTranslator(
        GeminiTextTranslator(({required system, required user}) async {
          prompt = user;
          return 'Chúng ta triển khai vào thứ Sáu';
        }),
        repo.termsIn,
      );

      await translator.translate(
        const TranslateRequest(
          from: 'en',
          to: 'vi',
          text: 'We deploy on Friday',
        ),
      );

      expect(prompt, contains('Glossary:\n- deploy = triển khai'));
      expect(prompt, endsWith('We deploy on Friday'));
    },
  );

  test('a glossary lookup failure does not stop the translation', () async {
    final translator = GlossaryTranslator(
      GeminiTextTranslator(({required system, required user}) async => 'ok'),
      (_) => Future.error(StateError('db closed')),
    );

    final result = await translator.translate(
      const TranslateRequest(from: 'en', to: 'vi', text: 'Hi'),
    );

    expect(result.text, 'ok');
  });
}

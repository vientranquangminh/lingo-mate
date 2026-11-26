import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/audio/playback_audio_capture.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/features/listen/data/notifier/listen_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/audio/audio_test_utils.dart';
import '../conversation/conversation_fakes.dart';

void main() {
  const languages = LanguagePair('en', 'vi');
  late ConversationFakes fakes;
  late FakeCapture playback;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'my_language': 'vi',
      'partner_languages': ['en'],
    });
    fakes = ConversationFakes()..prefs = await SharedPreferences.getInstance();
    playback = FakeCapture();
    addTearDown(fakes.db.close);
  });

  /// Builds a container with media Listen kept alive.
  Future<ProviderContainer> build() async {
    final c = ProviderContainer(
      overrides: [
        ...fakes.overrides(),
        listenClockProvider.overrideWithValue(() => fakes.nowMs),
        mediaCaptureProvider.overrideWithValue(playback),
      ],
    );
    addTearDown(c.dispose);
    c.listen(mediaListenProvider(languages), (_, _) {});
    await pumpEventQueue();
    return c;
  }

  test('media mode captions what the phone plays and saves a media session (AC-21.1)', () async {
    fakes.recognizer.texts.add('Welcome back to the show');
    final c = await build();
    final notifier = c.read(mediaListenProvider(languages).notifier);

    await notifier.start();
    fakes.nowMs += 1700;
    playback
      ..add(pcm(1000, amplitude: 4000))
      ..add(pcm(700));
    await pumpEventQueue();

    final state = c.read(mediaListenProvider(languages));
    expect(state.captions.single.translation, '[vi] Welcome back to the show');
    expect(fakes.capture.controller, isNull);
    await notifier.pause();
    c.dispose();
    await pumpEventQueue();
    final session = await fakes.db.select(fakes.db.sessions).getSingle();
    expect(session.mode, SessionMode.media.name);
  });

  test(
    '10 s of silence explains that the app may block capture (AC-21.2)',
    () async {
      final c = await build();
      final notifier = c.read(mediaListenProvider(languages).notifier);
      await notifier.start();

      fakes.nowMs += 11000;
      playback.add(pcm(500));
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(c.read(mediaListenProvider(languages)).mediaSilent, isTrue);

      playback.add(pcm(300, amplitude: 4000));
      await pumpEventQueue();
      expect(c.read(mediaListenProvider(languages)).mediaSilent, isFalse);
      await notifier.pause();
    },
  );
}

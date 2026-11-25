import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lingo_mate/core/audio/audio_capture.dart';
import 'package:lingo_mate/core/auth/auth_providers.dart';
import 'package:lingo_mate/core/audio/audio_frame.dart';
import 'package:lingo_mate/core/audio/voice_activity_detector.dart';
import 'package:lingo_mate/core/config/feature_switches.dart';
import 'package:lingo_mate/core/database/app_database.dart';
import 'package:lingo_mate/core/engines/engine_instances.dart';
import 'package:lingo_mate/core/engines/engines.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/engines/selection/engine_selector.dart';
import 'package:lingo_mate/core/engines/tts/speech_synthesizer.dart';
import 'package:lingo_mate/core/learning/learning_assistant.dart';
import 'package:lingo_mate/core/platform/home_widget.dart';
import 'package:lingo_mate/core/platform/mic_permission.dart';
import 'package:lingo_mate/core/quota/quota_engine.dart';
import 'package:lingo_mate/core/quota/quota_providers.dart';
import 'package:lingo_mate/core/sessions/session_repository.dart';
import 'package:lingo_mate/core/settings/user_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/learning/learning_fakes.dart';
import '../../helpers/fake_platform.dart';

import 'package:lingo_mate/features/conversation/data/notifier/conversation_notifier.dart';

/// Capture that streams whatever the test pushes.
class FakeCapture implements AudioCapture {
  FakeCapture({this.permitted = true});

  final bool permitted;
  StreamController<Uint8List>? controller;

  @override
  Future<bool> ensurePermission() async => permitted;

  @override
  Future<Stream<Uint8List>> start(AudioCaptureConfig config) async {
    controller = StreamController<Uint8List>();
    return controller!.stream;
  }

  @override
  Future<void> stop() async {
    await controller?.close();
    controller = null;
  }

  /// Pushes PCM bytes when the mic is open.
  void add(Uint8List bytes) => controller?.add(bytes);
}

/// Recognizer that returns the queued texts in order, tagged with the hint language; detection returns the queued languages.
class FakeRecognizer implements SpeechRecognizerEngine {
  final texts = <String>[];
  final hints = <String?>[];
  final detections = <String?>[];
  @override
  bool supportsPartials = false;

  @override
  Future<String?> detectLanguage(
    AudioSegment segment, {
    required List<String> candidates,
  }) async {
    final lang = detections.isEmpty ? null : detections.removeAt(0);
    return candidates.contains(lang) ? lang : null;
  }

  @override
  String get id => 'fake';

  @override
  Future<void> ensureReady(String lang) async {}

  @override
  Future<AsrResult> transcribe(AudioSegment segment, {String? hintLang}) async {
    hints.add(hintLang);
    return AsrResult(
      text: texts.isEmpty ? '' : texts.removeAt(0),
      lang: hintLang ?? '',
    );
  }
}

/// Translator that prefixes the target language, or fails when told to.
class FakeTranslator implements TextTranslatorEngine {
  FakeTranslator(this.kind);

  @override
  final EngineKind kind;
  bool fail = false;
  bool available = true;
  final requests = <TranslateRequest>[];
  final scripted = <String, String>{};
  Completer<void>? gate;

  @override
  String get id => kind.name;

  @override
  Future<bool> isAvailable(String from, String to) async => available;

  @override
  Future<Translation> translate(TranslateRequest request) async {
    requests.add(request);
    await gate?.future;
    if (fail) {
      throw StateError('down');
    }
    return Translation(
      text: scripted[request.text] ?? '[${request.to}] ${request.text}',
      engine: kind,
    );
  }
}

/// Synthesizer that records what it speaks; [hold] keeps playback going until [finish].
class FakeSynthesizer implements SpeechSynthesizerEngine {
  final spoken = <(String, String)>[];
  final missingVoices = <String>{};
  bool hold = false;
  Completer<void>? _playing;
  int stops = 0;

  @override
  Stream<TtsState> get state => const Stream.empty();

  @override
  Future<bool> supports(String lang) async => !missingVoices.contains(lang);

  @override
  Future<void> speak(String text, {required String lang, double rate = 1.0}) {
    spoken.add((text, lang));
    if (!hold) {
      return Future.value();
    }
    _playing = Completer<void>();
    return _playing!.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    finish();
  }

  /// Ends the current playback.
  void finish() {
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) {
      playing.complete();
    }
  }
}

/// Engine selection the test changes.
class FakeSelection extends Notifier<EngineSelection> {
  @override
  EngineSelection build() =>
      const EngineSelection(engine: EngineKind.standard, blocked: {});

  /// Sets the selection.
  void set(EngineSelection selection) => state = selection;
}

final fakeSelectionProvider = NotifierProvider<FakeSelection, EngineSelection>(
  FakeSelection.new,
);

/// Bundles the fakes and builds the overrides for them.
class ConversationFakes {
  FakeCapture capture = FakeCapture();
  final recognizer = FakeRecognizer();
  final standard = FakeTranslator(EngineKind.standard);
  final offline = FakeTranslator(EngineKind.offline);
  final tts = FakeSynthesizer();
  bool hasRecognizer = true;
  bool online = true;
  final learning = FakeLearningAssistant();
  FeatureSwitches? switches;
  QuotaLimits limits = const QuotaLimits(win5hSec: 1800, weekSec: 3600);
  final links = StreamController<Uri>.broadcast();
  final widget = FakeHomeWidget();
  int nowMs = 0;
  final db = AppDatabase(NativeDatabase.memory());
  late SharedPreferences prefs;

  /// Overrides every device-bound provider used by Conversation.
  List<Override> overrides({bool reviewEnabled = true}) => [
    audioCaptureProvider.overrideWith((ref) => capture),
    vadFactoryProvider.overrideWith(
      (ref) async => EnergyVoiceActivityDetector.new,
    ),
    speechRecognizerProvider.overrideWith(
      (ref) async => hasRecognizer ? recognizer : null,
    ),
    textTranslatorProvider.overrideWith(
      (ref, kind) => kind == EngineKind.offline ? offline : standard,
    ),
    speechSynthesizerProvider.overrideWithValue(tts),
    conversationClockProvider.overrideWithValue(() => nowMs),
    engineSelectionProvider.overrideWith(
      (ref, request) async => ref.watch(fakeSelectionProvider),
    ),
    onlineProvider.overrideWith((ref) => Stream.value(online)),
    learningAssistantProvider.overrideWithValue(learning),
    standardLimitsProvider.overrideWithValue(limits),
    incomingLinksProvider.overrideWithValue(links.stream),
    homeWidgetBridgeProvider.overrideWithValue(widget),
    featureSwitchesProvider.overrideWithValue(
      switches ?? FeatureSwitches(postSessionReview: reviewEnabled),
    ),
    appDatabaseProvider.overrideWithValue(db),
    micPermissionProvider.overrideWithValue(FakeMicPermission()),
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];

  /// The repository over the test database.
  SessionRepository get sessions => SessionRepository(db);
}

/// Records what the home screen widget was sent.
class FakeHomeWidget implements HomeWidgetBridge {
  final updates = <List<WidgetFavorite>>[];

  @override
  Future<void> update(List<WidgetFavorite> favorites) async =>
      updates.add(favorites);
}

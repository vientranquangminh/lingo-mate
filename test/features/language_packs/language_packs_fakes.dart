import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:lingo_mate/core/config/remote_config_service.dart';
import 'package:lingo_mate/core/config/remote_defaults.dart';
import 'package:lingo_mate/core/engines/selection/capability_matrix.dart';
import 'package:lingo_mate/core/engines/selection/engine_providers.dart';
import 'package:lingo_mate/core/errors/crash_reporter.dart';
import 'package:lingo_mate/features/language_packs/data/model/pack_models.dart';
import 'package:lingo_mate/features/language_packs/data/notifier/language_packs_notifier.dart';
import 'package:lingo_mate/features/language_packs/data/repository/pack_repository.dart';

/// Translation models kept in memory.
class FakeTranslationModels implements TranslationModels {
  final downloaded = <String>{};
  final downloads = <String>[];
  final wifiRequired = <bool>[];
  bool fail = false;

  @override
  Future<bool> isDownloaded(String lang) async => downloaded.contains(lang);

  @override
  Future<bool> download(String lang, {required bool wifiRequired}) async {
    downloads.add(lang);
    this.wifiRequired.add(wifiRequired);
    if (fail) {
      return false;
    }
    downloaded.add(lang);
    return true;
  }

  @override
  Future<bool> delete(String lang) async => downloaded.remove(lang);
}

/// Speech model files kept in memory; downloads finish when [complete] is called.
class FakeSpeechModelFiles implements SpeechModelFiles {
  final files = <String>{};
  final deleted = <String>[];
  Completer<void>? pending;
  void Function(double)? progress;

  @override
  Future<bool> exists(AsrModelSpec spec) async => files.contains(spec.fileName);

  @override
  Future<void> download(
    AsrModelSpec spec,
    void Function(double) onProgress,
  ) async {
    progress = onProgress;
    final gate = pending;
    if (gate != null) {
      await gate.future;
    }
    files.add(spec.fileName);
    onProgress(1);
  }

  @override
  Future<void> delete(AsrModelSpec spec) async {
    deleted.add(spec.fileName);
    files.remove(spec.fileName);
  }
}

/// Voice check with a fixed set of voices.
class FakeVoiceChecker implements VoiceChecker {
  FakeVoiceChecker([Set<String>? voices]) : voices = voices ?? {'en', 'vi'};

  final Set<String> voices;

  @override
  Future<bool> hasVoice(String lang) async => voices.contains(lang);
}

/// Wi-Fi state the test switches.
class FakeWifiState implements WifiState {
  bool onWifi = true;
  final controller = StreamController<void>.broadcast();

  @override
  Future<bool> isOnWifi() async => onWifi;

  @override
  Stream<void> get wifiConnected => controller.stream;

  /// Connects Wi-Fi and notifies listeners.
  void connect() {
    onWifi = true;
    controller.add(null);
  }
}

/// The bundled capability matrix.
CapabilityMatrix bundledMatrix() => CapabilityMatrix.fromJson(
  jsonDecode(File(CapabilityMatrix.assetPath).readAsStringSync())
      as Map<String, dynamic>,
);

/// Speech model specs used by the tests: English, Vietnamese and Japanese share one file.
const asrModelsJson = {
  'en': {
    'file': 'whisper-small.bin',
    'url': 'https://x/s.bin',
    'bytes': 104857600,
  },
  'vi': {
    'file': 'whisper-small.bin',
    'url': 'https://x/s.bin',
    'bytes': 104857600,
  },
  'ja': {
    'file': 'whisper-small.bin',
    'url': 'https://x/s.bin',
    'bytes': 104857600,
  },
  'ko': {
    'file': 'whisper-ko.bin',
    'url': 'https://x/ko.bin',
    'bytes': 52428800,
  },
};

/// Overrides every device-bound provider of the packs feature.
List<Override> packOverrides({
  required FakeTranslationModels translation,
  required FakeSpeechModelFiles speech,
  required FakeVoiceChecker voices,
  required FakeWifiState wifi,
}) => [
  capabilityMatrixProvider.overrideWith((ref) async => bundledMatrix()),
  engineRemoteConfigProvider.overrideWithValue(
    RemoteConfigService.withDefaults(CrashReporter.disabled(), {
      RemoteDefaults.asrModels: jsonEncode(asrModelsJson),
    }),
  ),
  translationModelsProvider.overrideWithValue(translation),
  speechModelFilesProvider.overrideWithValue(speech),
  voiceCheckerProvider.overrideWithValue(voices),
  wifiStateProvider.overrideWithValue(wifi),
  pushedSpeechModelsProvider.overrideWith((ref) async => false),
  packsInstalledProvider.overrideWith((ref, pair) async => false),
];

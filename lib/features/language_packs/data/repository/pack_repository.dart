import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../../../core/engines/asr/asr_models.dart';
import '../../../../core/engines/translate/mlkit_text_translator.dart';
import '../model/pack_models.dart';

/// ML Kit translation models per language.
abstract interface class TranslationModels {
  /// Whether the model for [lang] is on the device.
  Future<bool> isDownloaded(String lang);

  /// Downloads the model for [lang]; waits for Wi-Fi when [wifiRequired].
  Future<bool> download(String lang, {required bool wifiRequired});

  /// Removes the model for [lang].
  Future<bool> delete(String lang);
}

/// [TranslationModels] on ML Kit's model manager.
class MlKitTranslationModels implements TranslationModels {
  MlKitTranslationModels([OnDeviceTranslatorModelManager? manager])
    : _manager = manager ?? OnDeviceTranslatorModelManager();

  final OnDeviceTranslatorModelManager _manager;

  /// Returns ML Kit's code for [lang], or null when ML Kit has none.
  static String? _code(String lang) =>
      MlKitTextTranslator.languageFor(lang)?.bcpCode;

  @override
  Future<bool> isDownloaded(String lang) async {
    final code = _code(lang);
    return code != null && await _manager.isModelDownloaded(code);
  }

  @override
  Future<bool> download(String lang, {required bool wifiRequired}) async {
    final code = _code(lang);
    return code != null &&
        await _manager.downloadModel(code, isWifiRequired: wifiRequired);
  }

  @override
  Future<bool> delete(String lang) async {
    final code = _code(lang);
    return code != null && await _manager.deleteModel(code);
  }
}

/// Speech model files in the app's `models/` folder.
abstract interface class SpeechModelFiles {
  /// Whether the model file is present.
  Future<bool> exists(AsrModelSpec spec);

  /// Downloads the model, reporting progress from 0 to 1; throws on failure or checksum mismatch.
  Future<void> download(AsrModelSpec spec, void Function(double) onProgress);

  /// Removes the model file.
  Future<void> delete(AsrModelSpec spec);
}

/// [SpeechModelFiles] that streams downloads into the folder [AsrModelStore] scans.
class HttpSpeechModelFiles implements SpeechModelFiles {
  HttpSpeechModelFiles({Future<Directory> Function()? directory})
    : _directory =
          directory ?? (() async => (await AsrModelStore.open()).directory);

  final Future<Directory> Function() _directory;

  /// Returns the model file for [spec].
  Future<File> _file(AsrModelSpec spec) async =>
      File('${(await _directory()).path}/${spec.fileName}');

  /// Returns the folder a `.tar.bz2` model unpacks into.
  Future<Directory> _folder(AsrModelSpec spec) async =>
      Directory('${(await _directory()).path}/${spec.folderName}');

  @override
  Future<bool> exists(AsrModelSpec spec) async => spec.isArchive
      ? (await _folder(spec)).exists()
      : (await _file(spec)).exists();

  @override
  Future<void> download(
    AsrModelSpec spec,
    void Function(double) onProgress,
  ) async {
    final target = await _file(spec);
    final partial = File('${target.path}.part');
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(spec.url))).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: Uri.parse(spec.url),
        );
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : spec.bytes;
      final sink = partial.openWrite();
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress((received / total).clamp(0, 1));
        }
      }
      await sink.close();
      hasher.close();
      final expected = spec.sha256;
      if (expected != null &&
          digest.value.toString() != expected.toLowerCase()) {
        throw StateError('checksum mismatch for ${spec.fileName}');
      }
      if (spec.isArchive) {
        final root = (await _directory()).path;
        final path = partial.path;
        await Isolate.run(() => unpackTarBz2(path, root));
      } else {
        await partial.rename(target.path);
      }
      onProgress(1);
    } finally {
      client.close(force: true);
      if (await partial.exists()) {
        await partial.delete();
      }
    }
  }

  @override
  Future<void> delete(AsrModelSpec spec) async {
    if (spec.isArchive) {
      final folder = await _folder(spec);
      if (await folder.exists()) {
        await folder.delete(recursive: true);
      }
      return;
    }
    final file = await _file(spec);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Unpacks the `.tar.bz2` at [archivePath] into [root], skipping sample audio; the folder appears only once complete.
  static void unpackTarBz2(String archivePath, String root) {
    final tar = TarDecoder().decodeBytes(
      BZip2Decoder().decodeBytes(File(archivePath).readAsBytesSync()),
    );
    final staging = Directory('$root/.unpacking')..createSync(recursive: true);
    final tops = <String>{};
    try {
      for (final entry in tar.files) {
        final name = entry.name;
        if (!entry.isFile ||
            name.contains('..') ||
            name.contains('/test_wavs/') ||
            name.endsWith('.wav')) {
          continue;
        }
        tops.add(name.split('/').first);
        File('${staging.path}/$name')
          ..createSync(recursive: true)
          ..writeAsBytesSync(entry.content);
      }
      for (final top in tops) {
        final target = Directory('$root/$top');
        if (target.existsSync()) {
          target.deleteSync(recursive: true);
        }
        Directory('${staging.path}/$top').renameSync(target.path);
      }
    } finally {
      if (staging.existsSync()) {
        staging.deleteSync(recursive: true);
      }
    }
  }
}

/// Receives the final digest of a chunked hash.
class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Checks whether the device has a text-to-speech voice for a language.
abstract interface class VoiceChecker {
  /// Whether a voice for [lang] is installed.
  Future<bool> hasVoice(String lang);
}

/// [VoiceChecker] on the device TTS engine.
class TtsVoiceChecker implements VoiceChecker {
  TtsVoiceChecker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> hasVoice(String lang) async {
    try {
      return await _tts.isLanguageAvailable(lang) == true;
    } catch (_) {
      return false;
    }
  }
}

/// Reports whether the device is on Wi-Fi.
abstract interface class WifiState {
  /// Whether Wi-Fi is connected now.
  Future<bool> isOnWifi();

  /// Emits whenever Wi-Fi connects.
  Stream<void> get wifiConnected;
}

/// [WifiState] on connectivity_plus.
class ConnectivityWifiState implements WifiState {
  ConnectivityWifiState([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnWifi() async => (await _connectivity.checkConnectivity())
      .contains(ConnectivityResult.wifi);

  @override
  Stream<void> get wifiConnected => _connectivity.onConnectivityChanged.where(
    (r) => r.contains(ConnectivityResult.wifi),
  );
}

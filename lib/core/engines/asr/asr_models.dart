import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';

/// Files of a Whisper model exported to ONNX for sherpa-onnx.
class SherpaWhisperModel extends Equatable {
  const SherpaWhisperModel({
    required this.name,
    required this.encoder,
    required this.decoder,
    required this.tokens,
  });

  final String name;
  final String encoder;
  final String decoder;
  final String tokens;

  @override
  List<Object?> get props => [name, encoder, decoder, tokens];
}

/// Files of a zipformer transducer exported for sherpa-onnx, trained for one language.
class TransducerModel extends Equatable {
  const TransducerModel({
    required this.lang,
    required this.name,
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });

  final String lang;
  final String name;
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  @override
  List<Object?> get props => [lang, name, encoder, decoder, joiner, tokens];
}

/// A whisper.cpp GGML model file.
class WhisperCppModel extends Equatable {
  const WhisperCppModel({required this.name, required this.path});

  final String name;
  final String path;

  @override
  List<Object?> get props => [name, path];
}

/// Speech models found in the app's `models/` folder (pushed with adb during the spike, T-1.3 downloads them).
class AsrModelCatalog extends Equatable {
  const AsrModelCatalog({
    this.sherpaWhisper = const [],
    this.whisperCpp = const [],
    this.transducers = const [],
    this.sileroVad,
  });

  final List<SherpaWhisperModel> sherpaWhisper;
  final List<WhisperCppModel> whisperCpp;
  final List<TransducerModel> transducers;
  final String? sileroVad;

  bool get isEmpty =>
      sherpaWhisper.isEmpty && whisperCpp.isEmpty && transducers.isEmpty;

  @override
  List<Object?> get props => [
    sherpaWhisper,
    whisperCpp,
    transducers,
    sileroVad,
  ];
}

/// Finds speech models on disk.
class AsrModelStore {
  AsrModelStore(this.directory);

  final Directory directory;

  /// Opens the `models/` folder next to the benchmark folder on external app storage.
  static Future<AsrModelStore> open() async {
    final base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/models');
    await dir.create(recursive: true);
    return AsrModelStore(dir);
  }

  /// Writes [name] from [load] into the folder unless it is already there; returns its path.
  Future<String> installFile(
    String name,
    Future<Uint8List> Function() load,
  ) async {
    final file = File('${directory.path}/$name');
    if (!await file.exists()) {
      final temp = File('${file.path}.tmp');
      await temp.writeAsBytes(await load(), flush: true);
      await temp.rename(file.path);
    }
    return file.path;
  }

  /// Lists `ggml-*.bin` files, `sherpa-onnx-whisper-*` and `sherpa-onnx-zipformer-<lang>-*` folders and `silero_vad.onnx`.
  Future<AsrModelCatalog> scan() async {
    if (!await directory.exists()) {
      return const AsrModelCatalog();
    }
    final sherpa = <SherpaWhisperModel>[];
    final ggml = <WhisperCppModel>[];
    final transducers = <TransducerModel>[];
    String? silero;
    await for (final entity in directory.list()) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (entity is File && name == 'silero_vad.onnx') {
        silero = entity.path;
      } else if (entity is File &&
          name.startsWith('ggml-') &&
          name.endsWith('.bin')) {
        ggml.add(
          WhisperCppModel(
            name: name.substring(5, name.length - 4),
            path: entity.path,
          ),
        );
      } else if (entity is Directory &&
          name.startsWith('sherpa-onnx-whisper-')) {
        final model = await _sherpaModel(entity, name.substring(20));
        if (model != null) {
          sherpa.add(model);
        }
      } else if (entity is Directory && name.startsWith(zipformerPrefix)) {
        final model = await _transducerModel(entity, name);
        if (model != null) {
          transducers.add(model);
        }
      }
    }
    sherpa.sort((a, b) => a.name.compareTo(b.name));
    ggml.sort((a, b) => a.name.compareTo(b.name));
    return AsrModelCatalog(
      sherpaWhisper: sherpa,
      whisperCpp: ggml,
      transducers: transducers,
      sileroVad: silero,
    );
  }

  static const zipformerPrefix = 'sherpa-onnx-zipformer-';

  /// Returns the files of a transducer folder named `sherpa-onnx-zipformer-<lang>-…`, preferring int8 files.
  Future<TransducerModel?> _transducerModel(Directory dir, String name) async {
    final lang = name.substring(zipformerPrefix.length).split('-').first;
    final files = await _files(dir);
    final encoder = _pick(files, 'encoder');
    final decoder = _pick(files, 'decoder');
    final joiner = _pick(files, 'joiner');
    final tokens = _pick(files, 'tokens.txt');
    if (lang.isEmpty ||
        encoder == null ||
        decoder == null ||
        joiner == null ||
        tokens == null) {
      return null;
    }
    return TransducerModel(
      lang: lang,
      name: name,
      encoder: encoder,
      decoder: decoder,
      joiner: joiner,
      tokens: tokens,
    );
  }

  /// Lists the files directly in [dir].
  static Future<List<String>> _files(Directory dir) =>
      dir.list().where((e) => e is File).map((e) => e.path).toList();

  /// Returns the file whose name contains [part], preferring an int8 one.
  static String? _pick(List<String> files, String part) {
    final matches =
        files.where((f) => f.split('/').last.contains(part)).toList()..sort(
          (a, b) => (b.contains('int8') ? 1 : 0) - (a.contains('int8') ? 1 : 0),
        );
    return matches.isEmpty ? null : matches.first;
  }

  /// Returns the encoder, decoder and tokens of a sherpa Whisper folder, preferring int8 files.
  Future<SherpaWhisperModel?> _sherpaModel(Directory dir, String name) async {
    final files = await dir
        .list()
        .where((e) => e is File)
        .map((e) => e.path)
        .toList();
    String? pick(String part) {
      final matches = files.where((f) => f.contains(part)).toList()
        ..sort(
          (a, b) => (b.contains('int8') ? 1 : 0) - (a.contains('int8') ? 1 : 0),
        );
      return matches.isEmpty ? null : matches.first;
    }

    final encoder = pick('encoder');
    final decoder = pick('decoder');
    final tokens = pick('tokens.txt');
    if (encoder == null || decoder == null || tokens == null) {
      return null;
    }
    return SherpaWhisperModel(
      name: name,
      encoder: encoder,
      decoder: decoder,
      tokens: tokens,
    );
  }
}

/// Converts PCM16 samples to the -1…1 floats speech models expect.
Float32List pcm16ToFloat(Int16List samples) {
  final out = Float32List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = samples[i] / 32768;
  }
  return out;
}

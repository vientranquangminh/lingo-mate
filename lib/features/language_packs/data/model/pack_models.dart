import 'package:equatable/equatable.dart';

/// Where to download the speech model for a language (Remote Config `asr_models`).
class AsrModelSpec extends Equatable {
  const AsrModelSpec({
    required this.fileName,
    required this.url,
    required this.bytes,
    this.sha256,
  });

  /// Builds a spec from one `asr_models` entry; returns null when it is incomplete.
  static AsrModelSpec? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final file = json['file'];
    final url = json['url'];
    if (file is! String || url is! String || file.contains('/')) {
      return null;
    }
    return AsrModelSpec(
      fileName: file,
      url: url,
      bytes: json['bytes'] as int? ?? 0,
      sha256: json['sha256'] as String?,
    );
  }

  final String fileName;
  final String url;
  final int bytes;
  final String? sha256;

  static const _archiveSuffix = '.tar.bz2';

  /// Whether the download is a `.tar.bz2` holding a model folder (sherpa-onnx models).
  bool get isArchive => fileName.endsWith(_archiveSuffix);

  /// The folder an archive unpacks into: the file name without `.tar.bz2`.
  String get folderName => isArchive
      ? fileName.substring(0, fileName.length - _archiveSuffix.length)
      : fileName;

  @override
  List<Object?> get props => [fileName, url, bytes, sha256];
}

/// State of one downloadable part of a pack.
enum ComponentStatus { missing, waitingForWifi, downloading, ready, failed }

/// Overall state shown on a pack row (AC-06.1, AC-06.4, AC-06.7).
enum PackStatus {
  notAvailableOffline,
  notDownloaded,
  waitingForWifi,
  downloading,
  ready,
  failed,
}

/// The offline pack of one language: ML Kit translation model plus speech model.
class LanguagePack extends Equatable {
  const LanguagePack({
    required this.lang,
    required this.offlineSupported,
    this.translation = ComponentStatus.missing,
    this.speech = ComponentStatus.missing,
    this.speechSpec,
    this.speechProgress = 0,
    this.voiceMissing = false,
  });

  static const translationBytes = 30 * 1024 * 1024;

  final String lang;
  final bool offlineSupported;
  final ComponentStatus translation;
  final ComponentStatus speech;
  final AsrModelSpec? speechSpec;
  final double speechProgress;
  final bool voiceMissing;

  int get speechBytes => speechSpec?.bytes ?? 0;

  /// Bytes this pack uses on the device now.
  int get usedBytes =>
      (translation == ComponentStatus.ready ? translationBytes : 0) +
      (speech == ComponentStatus.ready ? speechBytes : 0);

  /// Whether anything of this pack is on the device or on its way.
  bool get started =>
      translation != ComponentStatus.missing ||
      speech != ComponentStatus.missing;

  /// Combines both parts into what the row shows.
  PackStatus get status {
    if (!offlineSupported) {
      return PackStatus.notAvailableOffline;
    }
    final parts = [translation, speech];
    if (parts.every((p) => p == ComponentStatus.ready)) {
      return PackStatus.ready;
    }
    if (parts.contains(ComponentStatus.failed)) {
      return PackStatus.failed;
    }
    if (parts.contains(ComponentStatus.downloading)) {
      return PackStatus.downloading;
    }
    if (parts.contains(ComponentStatus.waitingForWifi)) {
      return PackStatus.waitingForWifi;
    }
    return PackStatus.notDownloaded;
  }

  LanguagePack copyWith({
    ComponentStatus? translation,
    ComponentStatus? speech,
    double? speechProgress,
    bool? voiceMissing,
  }) {
    return LanguagePack(
      lang: lang,
      offlineSupported: offlineSupported,
      translation: translation ?? this.translation,
      speech: speech ?? this.speech,
      speechSpec: speechSpec,
      speechProgress: speechProgress ?? this.speechProgress,
      voiceMissing: voiceMissing ?? this.voiceMissing,
    );
  }

  @override
  List<Object?> get props => [
    lang,
    offlineSupported,
    translation,
    speech,
    speechSpec,
    speechProgress,
    voiceMissing,
  ];
}

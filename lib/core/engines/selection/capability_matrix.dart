import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import '../../config/remote_config_service.dart';
import '../../errors/crash_reporter.dart';
import '../engines.dart';

/// How well on-device speech recognition handles a language (set from the spike).
enum AsrQuality {
  good,
  fair,
  poor,
  none;

  /// Whether Offline and Standard may run on it; `poor` and `none` leave Live only.
  bool get usable => this == good || this == fair;

  /// Parses a matrix value, treating unknown values as [none].
  static AsrQuality parse(Object? value) =>
      AsrQuality.values.where((q) => q.name == value).firstOrNull ?? none;
}

/// What each engine can do for one language (doc 03 §8).
class LanguageCapability extends Equatable {
  const LanguageCapability({
    required this.code,
    required this.name,
    required this.offlineTranslate,
    required this.asrOnDevice,
    required this.live,
    required this.wave,
  });

  /// Builds a language entry from the matrix JSON.
  factory LanguageCapability.fromJson(String code, Map<String, dynamic> json) =>
      LanguageCapability(
        code: code,
        name: json['name'] as String? ?? code,
        offlineTranslate: json['offlineTranslate'] as bool? ?? false,
        asrOnDevice: AsrQuality.parse(json['asrOnDevice']),
        live: json['live'] as bool? ?? false,
        wave: json['wave'] as int? ?? 0,
      );

  final String code;
  final String name;
  final bool offlineTranslate;
  final AsrQuality asrOnDevice;
  final bool live;
  final int wave;

  @override
  List<Object?> get props => [
    code,
    name,
    offlineTranslate,
    asrOnDevice,
    live,
    wave,
  ];
}

/// Per-language engine support, from Remote Config or the bundled default.
class CapabilityMatrix extends Equatable {
  const CapabilityMatrix({required this.version, required this.languages});

  /// Parses the matrix JSON; throws [FormatException] when it is malformed.
  factory CapabilityMatrix.fromJson(Map<String, dynamic> json) {
    final languages = json['languages'];
    if (languages is! Map<String, dynamic>) {
      throw const FormatException('capability matrix has no languages');
    }
    return CapabilityMatrix(
      version: json['version'] as int? ?? 0,
      languages: {
        for (final MapEntry(:key, :value) in languages.entries)
          key: LanguageCapability.fromJson(key, value as Map<String, dynamic>),
      },
    );
  }

  static const assetPath = 'assets/capability_matrix.json';

  final int version;
  final Map<String, LanguageCapability> languages;

  /// Whether [engine] can translate between [from] and [to], given which of them are spoken.
  bool supports(
    EngineKind engine, {
    required String from,
    required String to,
    Set<String>? spoken,
  }) {
    final source = languages[from];
    final target = languages[to];
    if (source == null || target == null || from == to) {
      return false;
    }
    final heard = spoken ?? {from};
    bool asrOk(String code) => languages[code]!.asrOnDevice.usable;
    return switch (engine) {
      EngineKind.live => source.live && target.live,
      EngineKind.standard => heard.every(asrOk),
      EngineKind.offline =>
        source.offlineTranslate &&
            target.offlineTranslate &&
            heard.every(asrOk),
    };
  }

  @override
  List<Object?> get props => [version, languages];
}

/// Loads the matrix: the Remote Config override when valid, else the bundled asset (malformed overrides are reported).
class CapabilityMatrixLoader {
  CapabilityMatrixLoader(
    this._remoteConfig,
    this._crashReporter, {
    Future<String> Function()? readAsset,
  }) : _readAsset =
           readAsset ??
           (() => rootBundle.loadString(CapabilityMatrix.assetPath));

  final RemoteConfigService _remoteConfig;
  final CrashReporter _crashReporter;
  final Future<String> Function() _readAsset;

  /// Returns the matrix to use now.
  Future<CapabilityMatrix> load() async {
    final override = _remoteConfig.capabilityMatrix;
    if (override != null) {
      try {
        return CapabilityMatrix.fromJson(override);
      } catch (error, stack) {
        await _crashReporter.recordNonFatal(
          error,
          stack,
          reason: 'capability matrix override',
        );
      }
    }
    return CapabilityMatrix.fromJson(
      jsonDecode(await _readAsset()) as Map<String, dynamic>,
    );
  }
}

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:injectable/injectable.dart';

import '../../flavor_config.dart';
import '../errors/crash_reporter.dart';
import 'remote_defaults.dart';

/// Typed access to Remote Config values, falling back to [RemoteDefaults].
@lazySingleton
class RemoteConfigService {
  RemoteConfigService(this._crashReporter)
    : _remoteConfig = Firebase.apps.isEmpty
          ? null
          : FirebaseRemoteConfig.instance,
      _defaults = RemoteDefaults.values(liveEnabled: _isDevFlavor),
      _overrides = const {};

  RemoteConfigService.withDefaults(
    this._crashReporter, [
    this._overrides = const {},
  ]) : _remoteConfig = null,
       _defaults = RemoteDefaults.values(liveEnabled: _isDevFlavor);

  final FirebaseRemoteConfig? _remoteConfig;
  final Map<String, Object> _defaults;
  final Map<String, Object> _overrides;
  final CrashReporter _crashReporter;

  static bool get _isDevFlavor =>
      FlavorConfig.instance.appFlavor == Flavor.development;

  /// Applies defaults, activates the last fetched values and fetches new ones.
  Future<void> initialize() async {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      return;
    }
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: _isDevFlavor
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    await remoteConfig.setDefaults(_defaults);
    await remoteConfig.activate();
    remoteConfig.fetch().catchError(
      (Object error, StackTrace stack) =>
          _crashReporter.recordNonFatal(error, stack, reason: 'remote fetch'),
    );
  }

  /// Fires after values published in the console are activated, so kill switches apply without a restart.
  Stream<void> get updates {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      return const Stream.empty();
    }
    return remoteConfig.onConfigUpdated.asyncMap(
      (_) => remoteConfig.activate(),
    );
  }

  String get modelTextTranslate => _string(RemoteDefaults.modelTextTranslate);
  String get modelTextReview => _string(RemoteDefaults.modelTextReview);
  String get modelSpeechTranslate =>
      _string(RemoteDefaults.modelSpeechTranslate);
  String get privacyPolicyUrl => _string(RemoteDefaults.privacyPolicyUrl);
  String get modelLiveTranslate => _string(RemoteDefaults.modelLiveTranslate);
  String get modelLiveFallback => _string(RemoteDefaults.modelLiveFallback);
  int get liveBlockSec => _int(RemoteDefaults.liveBlockSec);
  int get minSupportedBuild => _int(RemoteDefaults.minSupportedBuild);
  bool get liveEnabled => _bool(RemoteDefaults.ffLiveEnabled);
  bool get meetingOverlayEnabled => _bool(RemoteDefaults.ffMeetingOverlay);
  bool get postSessionReviewEnabled =>
      _bool(RemoteDefaults.ffPostSessionReview);
  bool get standardEnabled => _bool(RemoteDefaults.ffStandardEnabled);
  bool get summaryEnabled => _bool(RemoteDefaults.ffSummary);
  bool get suggestReplyEnabled => _bool(RemoteDefaults.ffSuggestReply);
  bool get glossaryEnabled => _bool(RemoteDefaults.ffGlossary);
  bool get cloudSpeechEnabled => _bool(RemoteDefaults.ffCloudSpeech);
  bool get roleplayEnabled => _bool(RemoteDefaults.ffRoleplay);
  bool get paywallEnabled => _bool(RemoteDefaults.ffPaywall);
  bool get emailLinkSigninEnabled => _bool(RemoteDefaults.ffEmailLinkSignin);
  bool get manageSubscriptionEnabled =>
      _bool(RemoteDefaults.ffManageSubscription);

  /// Returns the quota limits per plan, or the defaults when the value is not valid JSON.
  Map<String, dynamic> get quotaLimits =>
      _json(RemoteDefaults.quotaLimits) ??
      _defaultJson(RemoteDefaults.quotaLimits)!;

  /// Returns the speech model to download per language (`{lang: {file, url, bytes, sha256}}`), empty until OQ-3 picks the library.
  Map<String, dynamic> get asrModels =>
      _json(RemoteDefaults.asrModels) ?? const {};

  /// Returns the capability matrix override, or null when none is set or it is invalid.
  Map<String, dynamic>? get capabilityMatrix =>
      _json(RemoteDefaults.capabilityMatrix);

  /// Returns every key with its current value and where it came from, for the devtools viewer.
  Map<String, String> snapshot() => {
    for (final key in _defaults.keys)
      key: _remoteConfig == null
          ? '${_local(key)} (in-app)'
          : '${_remoteConfig.getString(key)} '
                '(${_remoteConfig.getValue(key).source.name})',
  };

  /// Reads a string value.
  String _string(String key) =>
      _remoteConfig?.getString(key) ?? _local(key) as String;

  /// Reads an integer value.
  int _int(String key) => _remoteConfig?.getInt(key) ?? _local(key) as int;

  /// Reads a boolean value.
  bool _bool(String key) => _remoteConfig?.getBool(key) ?? _local(key) as bool;

  /// Returns the override or in-app default used when Firebase is not available.
  Object _local(String key) => _overrides[key] ?? _defaults[key]!;

  /// Parses a JSON object value, reporting a non-fatal error when it is malformed.
  Map<String, dynamic>? _json(String key) {
    final raw = _string(key);
    if (raw.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stack) {
      _crashReporter.recordNonFatal(error, stack, reason: 'remote json $key');
      return null;
    }
  }

  /// Parses the in-app default of a JSON value.
  Map<String, dynamic>? _defaultJson(String key) {
    final raw = _defaults[key]! as String;
    return raw.isEmpty ? null : jsonDecode(raw) as Map<String, dynamic>;
  }
}

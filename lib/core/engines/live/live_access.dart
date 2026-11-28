import 'package:cloud_functions/cloud_functions.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../env.dart';
import '../../../flavor_config.dart';
import '../selection/engine_selector.dart';
import 'live_models.dart';

/// Why Live was refused.
enum LiveDenial { signInRequired, quota, unavailable }

/// The answer to a Live request: credentials and a time block, or why not (doc 03 §10).
class LiveGrant extends Equatable {
  const LiveGrant.allowed({
    required LiveCredentials this.credentials,
    required this.blockSec,
    this.tokenId,
    this.expiresAt,
  }) : denial = null,
       resetAt = null;

  const LiveGrant.denied(LiveDenial this.denial, {this.resetAt})
    : credentials = null,
      blockSec = 0,
      tokenId = null,
      expiresAt = null;

  final LiveCredentials? credentials;
  final int blockSec;
  final String? tokenId;
  final DateTime? expiresAt;
  final LiveDenial? denial;
  final DateTime? resetAt;

  bool get allowed => credentials != null;

  @override
  List<Object?> get props => [
    credentials,
    blockSec,
    tokenId,
    expiresAt,
    denial,
    resetAt,
  ];
}

/// Gets permission to open Live sessions and reports how much of a block was used.
abstract interface class LiveAccess {
  /// Asks for a Live block translating into [target] for [mode].
  Future<LiveGrant> request({
    required String target,
    required SessionMode mode,
  });

  /// Reports that [usedSec] of the block behind [tokenId] were used, so the rest is refunded (AC-14.4).
  Future<void> report(String tokenId, int usedSec);
}

/// Dev flavor: the API key from `.env.dev`, ten-minute blocks, nothing reported.
class DevLiveAccess implements LiveAccess {
  const DevLiveAccess(this.apiKey);

  final String apiKey;

  @override
  Future<LiveGrant> request({
    required String target,
    required SessionMode mode,
  }) async => apiKey.isEmpty
      ? const LiveGrant.denied(LiveDenial.unavailable)
      : LiveGrant.allowed(credentials: LiveApiKey(apiKey), blockSec: 600);

  @override
  Future<void> report(String tokenId, int usedSec) async {}
}

/// Production: ephemeral tokens from the `issueLiveToken` function and refunds through `reportLiveUsage`.
class CallableLiveAccess implements LiveAccess {
  CallableLiveAccess([FirebaseFunctions? functions])
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<LiveGrant> request({
    required String target,
    required SessionMode mode,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('issueLiveToken')
          .call<Object?>({
            'targetLangs': [target],
            'mode': mode.name,
          });
      return parse(result.data);
    } on FirebaseFunctionsException catch (e) {
      return e.code == 'unauthenticated'
          ? const LiveGrant.denied(LiveDenial.signInRequired)
          : const LiveGrant.denied(LiveDenial.unavailable);
    }
  }

  @override
  Future<void> report(String tokenId, int usedSec) async {
    try {
      await _functions.httpsCallable('reportLiveUsage').call<Object?>({
        'tokenId': tokenId,
        'usedSec': usedSec,
      });
    } on FirebaseFunctionsException {
      return;
    }
  }

  /// Reads the `issueLiveToken` answer.
  static LiveGrant parse(Object? data) {
    final map = data is Map ? data : const {};
    DateTime? time(Object? value) => value is num
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
        : value is String
        ? DateTime.tryParse(value)
        : null;
    if (map['allowed'] != true) {
      return LiveGrant.denied(switch (map['reason']) {
        'sign_in_required' => LiveDenial.signInRequired,
        'quota' || 'limit' => LiveDenial.quota,
        _ => map['resetAt'] != null ? LiveDenial.quota : LiveDenial.unavailable,
      }, resetAt: time(map['resetAt']));
    }
    final tokens = map['tokens'];
    final token = tokens is List && tokens.isNotEmpty
        ? '${tokens.first}'
        : null;
    if (token == null) {
      return const LiveGrant.denied(LiveDenial.unavailable);
    }
    final block = map['blockSec'];
    return LiveGrant.allowed(
      credentials: LiveEphemeralToken(token),
      blockSec: block is num ? block.toInt() : 600,
      tokenId: map['tokenId'] as String?,
      expiresAt: time(map['expiresAt']),
    );
  }
}

/// Live access for this build: the dev key in dev, the functions where Firebase is set up, else none.
final liveAccessProvider = Provider<LiveAccess>((ref) {
  if (FlavorConfig.instance.appFlavor == Flavor.development &&
      Env.geminiApiKey.isNotEmpty) {
    return DevLiveAccess(Env.geminiApiKey);
  }
  if (Firebase.apps.isNotEmpty) {
    return CallableLiveAccess();
  }
  return const DevLiveAccess('');
});

/// Whether Live needs a signed-in account: not on a dev or test build that carries its own Gemini key, where no server token is involved.
final liveNeedsAccountProvider = Provider<bool>((ref) {
  final access = ref.watch(liveAccessProvider);
  return access is! DevLiveAccess || access.apiKey.isEmpty;
});

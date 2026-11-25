import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../phrases/phrase_repository.dart';
import '../review/review_settings.dart';
import '../sessions/session_repository.dart';
import '../settings/user_settings.dart';
import 'cloud_store.dart';
import 'firestore_cloud_store.dart';
import 'sync_engine.dart';

/// Whether sync is on and when it last finished a step.
class SyncState extends Equatable {
  const SyncState({
    this.enabled = false,
    this.active = false,
    this.lastSyncedAt,
  });

  final bool enabled;
  final bool active;
  final DateTime? lastSyncedAt;

  @override
  List<Object?> get props => [enabled, active, lastSyncedAt];
}

/// The cloud copy, or null in builds without Firebase.
final cloudStoreProvider = Provider<CloudStore?>(
  (ref) => Firebase.apps.isEmpty ? null : FirestoreCloudStore(),
);

/// Sync of the phrasebook, review cards and glossaries; runs while it is on and a real account is signed in (F-13).
final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Starts and stops [SyncEngine] as the account and the setting change.
class SyncController extends Notifier<SyncState> {
  static const _enabled = 'sync_enabled';

  SyncEngine? _engine;
  StreamSubscription<DateTime>? _ticks;

  @override
  SyncState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool(_enabled) ?? false;
    final user = ref.watch(authUserProvider).value;
    final store = ref.watch(cloudStoreProvider);
    ref.onDispose(_stopEngine);
    final run = enabled && store != null && user != null && !user.isAnonymous;
    if (run) {
      unawaited(_startEngine(store, user.uid));
    }
    return SyncState(enabled: enabled, active: run);
  }

  /// Turns sync on or off.
  Future<void> setEnabled(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_enabled, value);
    ref.invalidateSelf();
  }

  /// Starts the engine for [uid] and writes the profile.
  Future<void> _startEngine(CloudStore store, String uid) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final key = 'sync_last_push_$uid';
    final engine = SyncEngine(
      ref.read(appDatabaseProvider),
      store,
      uid,
      lastPush: () => prefs.getInt(key) ?? 0,
      savePush: (ms) => prefs.setInt(key, ms),
    );
    _engine = engine;
    _ticks = engine.synced.listen((at) {
      if (ref.mounted) {
        state = SyncState(enabled: true, active: true, lastSyncedAt: at);
      }
    });
    await engine.start();
    await _pushProfile(store, uid);
  }

  /// Writes the profile and local stats to `users/{uid}` (doc 03 §9.2).
  Future<void> _pushProfile(CloudStore store, String uid) async {
    final user = ref.read(authServiceProvider).currentUser;
    final settings = ref.read(userSettingsProvider);
    final phrases = await ref.read(phraseRepositoryProvider).watchCount().first;
    final seconds = await ref
        .read(sessionRepositoryProvider)
        .watchTotalSeconds()
        .first;
    await store.putProfile(uid, {
      'displayName': user?.displayName,
      'email': user?.email,
      'photoUrl': user?.photoUrl,
      'provider': user?.provider.name,
      'myLanguages': [?settings.myLanguage, ...settings.partnerLanguages],
      'uiLocale': settings.appLocale,
      'stats': {
        'translatedSec': seconds,
        'phrasesSaved': phrases,
        'streakDays': ref.read(reviewSettingsProvider).streakOn(DateTime.now()),
      },
    });
  }

  /// Stops the running engine.
  void _stopEngine() {
    unawaited(_ticks?.cancel());
    _ticks = null;
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      unawaited(engine.stop());
    }
  }
}

/// Applies the merge choice after signing in to an account that already existed: keep and upload this phone's phrases, or replace them with the account's (AC-13.4).
final accountMergeProvider =
    Provider<Future<void> Function({required bool merge})>(
      (ref) => ({required bool merge}) async {
        if (!merge) {
          await ref.read(appDatabaseProvider).wipeLearningData();
        }
      },
    );

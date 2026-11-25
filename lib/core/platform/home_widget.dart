import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/selection/engine_selector.dart';
import '../quick_phrases/quick_phrases.dart';
import '../settings/user_settings.dart';

/// A favourite quick phrase shown on the home screen widget.
class WidgetFavorite extends Equatable {
  const WidgetFavorite({required this.key, required this.label});

  final String key;
  final String label;

  @override
  List<Object?> get props => [key, label];
}

/// Sends the widget its content (`HomeWidget.kt`).
abstract interface class HomeWidgetBridge {
  /// Shows [favorites] on every home screen widget.
  Future<void> update(List<WidgetFavorite> favorites);
}

/// [HomeWidgetBridge] over the `lingomate/home_widget` channel.
class ChannelHomeWidgetBridge implements HomeWidgetBridge {
  const ChannelHomeWidgetBridge();

  static const _channel = MethodChannel('lingomate/home_widget');

  @override
  Future<void> update(List<WidgetFavorite> favorites) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'favorites': jsonEncode([
          for (final f in favorites) {'key': f.key, 'label': f.label},
        ]),
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

/// The home widget bridge.
final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>(
  (ref) => const ChannelHomeWidgetBridge(),
);

/// Keeps the widget's favourites in line with the starred quick phrases of the current pair (AC-23.1).
final homeWidgetSyncProvider = Provider<void>((ref) {
  final pair = ref.watch(userSettingsProvider.select((s) => s.pair));
  final catalog = ref.watch(quickPhraseCatalogProvider).value;
  final keys = ref.watch(quickFavoriteKeysProvider(pair)).value;
  if (catalog == null || keys == null) {
    return;
  }
  final favorites = [
    for (final key in keys.take(4))
      if (catalog.phrase(key) case final phrase?)
        WidgetFavorite(key: key, label: phrase.text(pair.a)),
  ];
  ref.read(homeWidgetBridgeProvider).update(favorites);
});

/// Where a `lingomate://open/...` link leads.
sealed class AppLink extends Equatable {
  const AppLink();

  /// Reads [uri], or null when it is not an app link.
  static AppLink? parse(Uri uri) {
    if (uri.scheme != 'lingomate' || uri.host != 'open') {
      return null;
    }
    return switch (uri.path) {
      '/conversation' => const ConversationLink(),
      '/meeting' => MeetingLink(start: uri.queryParameters['start'] == '1'),
      '/quick' when (uri.queryParameters['key'] ?? '').isNotEmpty =>
        QuickPhraseLink(uri.queryParameters['key']!),
      _ => null,
    };
  }

  @override
  List<Object?> get props => [];
}

/// Start a conversation on the current pair.
class ConversationLink extends AppLink {
  const ConversationLink();
}

/// Open Meeting, starting captions when [start].
class MeetingLink extends AppLink {
  const MeetingLink({this.start = false});

  final bool start;

  @override
  List<Object?> get props => [start];
}

/// Say or show quick phrase [key].
class QuickPhraseLink extends AppLink {
  const QuickPhraseLink(this.key);

  final String key;

  @override
  List<Object?> get props => [key];
}

/// The language pair app links use.
LanguagePair appLinkPair(Ref ref) => ref.read(userSettingsProvider).pair;

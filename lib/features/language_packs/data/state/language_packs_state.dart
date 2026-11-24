import 'package:equatable/equatable.dart';

import '../model/pack_models.dart';

/// Offline packs of every language in the capability matrix, plus download settings.
class LanguagePacksState extends Equatable {
  const LanguagePacksState({
    this.loading = true,
    this.packs = const [],
    this.wifiOnly = true,
    this.askMobileDataFor,
  });

  final bool loading;
  final List<LanguagePack> packs;
  final bool wifiOnly;
  final String? askMobileDataFor;

  /// Bytes used by all packs.
  int get usedBytes => packs.fold(0, (n, p) => n + p.usedBytes);

  /// Returns the pack of [lang].
  LanguagePack? pack(String lang) =>
      packs.where((p) => p.lang == lang).firstOrNull;

  LanguagePacksState copyWith({
    bool? loading,
    List<LanguagePack>? packs,
    bool? wifiOnly,
    String? Function()? askMobileDataFor,
  }) {
    return LanguagePacksState(
      loading: loading ?? this.loading,
      packs: packs ?? this.packs,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      askMobileDataFor: askMobileDataFor != null
          ? askMobileDataFor()
          : this.askMobileDataFor,
    );
  }

  @override
  List<Object?> get props => [loading, packs, wifiOnly, askMobileDataFor];
}

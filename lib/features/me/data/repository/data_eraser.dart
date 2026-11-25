import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/sessions/session_repository.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../../core/settings/user_settings.dart';
import '../../../language_packs/data/notifier/language_packs_notifier.dart';

/// Deletes the database, preferences and, when [models] is true, downloaded language packs; onboarding starts again (AC-10.3).
Future<void> deleteAllData(Ref ref, {required bool models}) async {
  if (models) {
    await ref.read(languagePacksProvider.notifier).deleteAll();
  }
  await ref.read(appDatabaseProvider).wipe();
  await ref.read(sharedPreferencesProvider).clear();
  ref
    ..invalidate(appPreferencesProvider)
    ..invalidate(enginePinProvider)
    ..invalidate(languagePacksProvider)
    ..invalidate(userSettingsProvider);
}

/// Runs [deleteAllData] from a widget.
final dataEraserProvider =
    Provider<Future<void> Function({required bool models})>(
      (ref) =>
          ({required bool models}) => deleteAllData(ref, models: models),
    );

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/phrases/phrase_repository.dart';
import '../extensions/build_context_ext.dart';
import 'app_toast.dart';

/// Saves a line from [source] to the phrasebook and confirms with a toast, or says it is already there (AC-02.6, AC-08.1, AC-08.2).
Future<SaveResult?> saveToPhrasebook(
  BuildContext context,
  WidgetRef ref, {
  required String sourceLang,
  required String sourceText,
  required String targetLang,
  required String targetText,
  required String source,
  String? fromUtteranceId,
}) async {
  final l10n = context.localization;
  final result = await ref
      .read(phraseRepositoryProvider)
      .save(
        sourceLang: sourceLang,
        sourceText: sourceText,
        targetLang: targetLang,
        targetText: targetText,
        fromUtteranceId: fromUtteranceId,
      );
  if (result.outcome == SaveOutcome.saved) {
    unawaited(ref.read(analyticsProvider).phraseSaved(source: source));
  }
  if (context.mounted) {
    showAppToast(
      context,
      result.outcome == SaveOutcome.saved
          ? l10n.phraseSaved
          : l10n.phraseDuplicate,
    );
  }
  return result;
}

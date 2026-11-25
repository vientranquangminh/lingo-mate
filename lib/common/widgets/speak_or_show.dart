import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engines/engine_instances.dart';
import '../../navigation/route_const.dart';
import '../extensions/build_context_ext.dart';

/// Opens show mode S-15 for [text]; [lang] adds a speak button and [hint] a note above the text.
void openShowMode(
  BuildContext context, {
  required String text,
  String? original,
  String? lang,
  String? hint,
}) => context.pushNamed(
  AppRouteName.showMode,
  extra: <String, String?>{
    'text': text,
    'original': original,
    'lang': lang,
    'hint': hint,
  },
);

/// Speaks [text] in [lang] when a voice is installed, otherwise opens show mode with a hint to install one (AC-09.2).
Future<void> speakOrShow(
  BuildContext context,
  WidgetRef ref, {
  required String text,
  required String lang,
  String? original,
}) async {
  final tts = ref.read(speechSynthesizerProvider);
  if (await tts.supports(lang)) {
    await tts.speak(text, lang: lang);
    return;
  }
  if (context.mounted) {
    openShowMode(
      context,
      text: text,
      original: original,
      hint: context.localization.quickVoiceMissing,
    );
  }
}

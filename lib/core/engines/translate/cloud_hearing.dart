import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/audio_frame.dart';
import '../engine_instances.dart';
import '../engines.dart';
import '../selection/engine_providers.dart';
import 'gemini_speech_translator.dart';

/// Gemini's answer for a sentence; [handled] false means the on-device path should run, [heard] null means nothing was said.
typedef CloudHearing = ({bool handled, SpeechTranslation? heard});

/// On the Standard engine, has Gemini hear and translate [segment] spoken in one of [from]; not handled when switched off or the call fails.
Future<CloudHearing> hearOnCloud(
  Ref ref, {
  required EngineKind? engine,
  required AudioSegment segment,
  required List<String> from,
  required String to,
  List<String> context = const [],
}) async {
  final cloud = ref.read(speechTranslatorProvider);
  if (cloud == null || engine != EngineKind.standard) {
    return (handled: false, heard: null);
  }
  try {
    final heard = await cloud.translate(
      segment: segment,
      from: from,
      to: to,
      context: context,
    );
    if (ref.mounted) {
      ref.read(errorBurstProvider).recordSuccess();
    }
    return (handled: true, heard: heard);
  } catch (error) {
    if (ref.mounted && GeminiSpeechTranslator.isRegionBlocked(error)) {
      await ref.read(regionBlockProvider.notifier).block(DateTime.now());
    }
    return (handled: false, heard: null);
  }
}

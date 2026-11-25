import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/settings/app_preferences.dart';

/// Scales caption and transcript text by the user's caption size, on top of the system text size.
class CaptionScale extends ConsumerWidget {
  const CaptionScale({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(
      appPreferencesProvider.select((p) => p.captionSize.scale),
    );
    if (scale == 1) {
      return child;
    }
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(media.textScaler.scale(1) * scale),
      ),
      child: child,
    );
  }
}

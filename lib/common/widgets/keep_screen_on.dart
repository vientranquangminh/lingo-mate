import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/platform/system_settings.dart';
import '../../core/settings/app_preferences.dart';

/// Keeps the screen awake while [child] is shown, when the user's setting allows it.
class KeepScreenOn extends ConsumerStatefulWidget {
  const KeepScreenOn({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KeepScreenOn> createState() => _KeepScreenOnState();
}

class _KeepScreenOnState extends ConsumerState<KeepScreenOn> {
  late final SystemSettings _system = ref.read(systemSettingsProvider);

  @override
  void initState() {
    super.initState();
    _system.keepScreenOn(ref.read(appPreferencesProvider).keepScreenOn);
  }

  @override
  void dispose() {
    _system.keepScreenOn(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      appPreferencesProvider.select((p) => p.keepScreenOn),
      (_, on) => _system.keepScreenOn(on),
    );
    return widget.child;
  }
}

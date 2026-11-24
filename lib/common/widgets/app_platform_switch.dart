import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';

/// On/off switch that uses the Material or the Cupertino look.
class AppPlatformSwitch extends StatelessWidget {
  const AppPlatformSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoSwitch(value: value, onChanged: onChanged);
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

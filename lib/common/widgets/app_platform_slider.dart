import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';

/// Slider that uses the Material or the Cupertino look; [divisions] makes it snap to steps.
class AppPlatformSlider extends StatelessWidget {
  const AppPlatformSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.semanticLabel,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final slider = context.isCupertino
        ? CupertinoSlider(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            divisions: divisions,
          )
        : Slider(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            divisions: divisions,
          );
    final label = semanticLabel;
    return label == null ? slider : Semantics(label: label, child: slider);
  }
}

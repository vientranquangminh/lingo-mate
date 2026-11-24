import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_switch.dart';

/// Heading above a group of devtools controls.
class DevtoolsSectionTitle extends StatelessWidget {
  const DevtoolsSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: AppParams.spacing24.h,
        bottom: AppParams.spacing8.h,
      ),
      child: Text(
        text,
        style: context.textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// A labelled on/off switch row.
class DevtoolsToggle extends StatelessWidget {
  const DevtoolsToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppParams.spacing4.h),
      child: Row(
        children: [
          Expanded(child: DevtoolsText(label)),
          AppPlatformSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Body text in the devtools screen.
class DevtoolsText extends StatelessWidget {
  const DevtoolsText(this.text, {super.key, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final role = small
        ? context.textTheme.bodySmall
        : context.textTheme.bodyMedium;
    return Text(
      text,
      style: role?.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

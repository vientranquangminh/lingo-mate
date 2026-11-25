import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';
import 'app_circle_icon_button.dart';
import 'app_icon.dart';

/// Search box in the Material or Cupertino look, with a clear button.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.clearLabel,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String clearLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (context.isCupertino) {
      return CupertinoSearchTextField(
        controller: controller,
        placeholder: hint,
        onChanged: onChanged,
      );
    }
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          prefixIcon: Padding(
            padding: EdgeInsets.all(AppParams.spacing12.r),
            child: AppIcon(
              AppIcons.search,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : AppCircleIconButton(
                  icon: AppIcons.close,
                  semanticLabel: clearLabel,
                  color: scheme.onSurfaceVariant,
                  borderColor: Colors.transparent,
                  size: 40,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppParams.spacing16.w,
            vertical: AppParams.spacing12.h,
          ),
        ),
      ),
    );
  }
}

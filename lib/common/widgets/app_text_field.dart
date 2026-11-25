import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';

/// Multi-line text input with a label, in the Material or Cupertino look.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoTextField(
        controller: controller,
        placeholder: label,
        onChanged: onChanged,
        minLines: minLines,
        maxLines: maxLines,
        padding: EdgeInsets.all(AppParams.spacing12.r),
      );
    }
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
        ),
      ),
    );
  }
}

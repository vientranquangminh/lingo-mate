import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';
import '../resources/app_params.dart';

/// Shows a Material or Cupertino time picker starting at [initial]; returns the chosen time or null.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initial,
  required String doneLabel,
}) async {
  if (!context.isCupertino) {
    return showTimePicker(context: context, initialTime: initial);
  }
  var picked = initial;
  final done = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => Container(
      height: AppParams.timePickerHeight.h,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CupertinoButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(doneLabel),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  2000,
                  1,
                  1,
                  initial.hour,
                  initial.minute,
                ),
                onDateTimeChanged: (time) =>
                    picked = TimeOfDay(hour: time.hour, minute: time.minute),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return done == true ? picked : null;
}

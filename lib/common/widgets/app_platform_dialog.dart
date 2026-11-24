import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';

/// Shows a two-choice dialog in the Material or Cupertino look; returns true for [confirm], false for [cancel], null when dismissed.
Future<bool?> showAppPlatformDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirm,
  required String cancel,
  bool destructive = false,
}) {
  if (context.isCupertino) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            child: Text(confirm),
          ),
        ],
      );
    },
  );
}

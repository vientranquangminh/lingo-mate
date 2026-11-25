import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/platform_ext.dart';

/// Asks for one line of text in the Material or Cupertino look; returns it, or null when cancelled.
Future<String?> showAppTextInputDialog({
  required BuildContext context,
  required String title,
  required String initialValue,
  required String confirm,
  required String cancel,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      confirm: confirm,
      cancel: cancel,
    ),
  );
}

/// The dialog body; owns the text controller.
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.confirm,
    required this.cancel,
  });

  final String title;
  final String initialValue;
  final String confirm;
  final String cancel;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Closes with the typed text.
  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoAlertDialog(
        title: Text(widget.title),
        content: CupertinoTextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.cancel),
          ),
          CupertinoDialogAction(
            onPressed: _submit,
            child: Text(widget.confirm),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}

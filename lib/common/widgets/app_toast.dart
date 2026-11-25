import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';
import 'app_platform_text_button.dart';

/// Shows a short message at the bottom of the screen (doc 08 Toast): 3 s, or [AppParams.undoDuration] with an action such as Undo; [overlay] is for callers outside a page.
void showAppToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  OverlayState? overlay,
}) {
  final target = overlay ?? Overlay.maybeOf(context, rootOverlay: true);
  if (target == null) {
    return;
  }
  late final OverlayEntry entry;
  Timer? timer;
  void close() {
    timer?.cancel();
    if (entry.mounted) {
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (context) => _Toast(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              close();
              onAction();
            },
    ),
  );
  target.insert(entry);
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
  timer = Timer(
    onAction == null ? AppParams.toastDuration : AppParams.undoDuration,
    close,
  );
}

/// The toast pill.
class _Toast extends StatelessWidget {
  const _Toast({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = actionLabel;
    final text = Text(
      message,
      textAlign: action == null ? TextAlign.center : TextAlign.start,
      style: context.textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
    );
    return Positioned(
      left: AppParams.spacing24.w,
      right: AppParams.spacing24.w,
      bottom: MediaQuery.paddingOf(context).bottom + AppParams.spacing32.h,
      child: Center(
        child: Material(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppParams.spacing20.w,
              vertical: action == null ? AppParams.spacing12.h : 0,
            ),
            child: action == null || onAction == null
                ? IgnorePointer(child: text)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: text),
                      SizedBox(width: AppParams.spacing8.w),
                      AppPlatformTextButton(
                        onPressed: onAction,
                        text: action,
                        color: scheme.inversePrimary,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/semantics.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../extensions/build_context_ext.dart';
import '../resources/app_params.dart';

/// Shows a short message at the bottom of the screen for 3 s (doc 08 Toast).
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (context) => _Toast(message: message));
  overlay.insert(entry);
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
  Timer(AppParams.toastDuration, () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}

/// The toast pill.
class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: AppParams.spacing24.w,
      right: AppParams.spacing24.w,
      bottom: MediaQuery.paddingOf(context).bottom + AppParams.spacing32.h,
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: scheme.inverseSurface,
            borderRadius: BorderRadius.circular(AppParams.radiusChip.r),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppParams.spacing20.w,
                vertical: AppParams.spacing12.h,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

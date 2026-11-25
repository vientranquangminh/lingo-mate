import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../core/engines/engine_instances.dart';

/// Show mode S-15: one line in large text for the other person to read, turnable 180°, with speak when [lang] is given (AC-09.4).
class ShowModePage extends ConsumerStatefulWidget {
  const ShowModePage({
    super.key,
    required this.text,
    this.original,
    this.lang,
    this.hint,
  });

  final String text;
  final String? original;
  final String? lang;
  final String? hint;

  @override
  ConsumerState<ShowModePage> createState() => _ShowModePageState();
}

class _ShowModePageState extends ConsumerState<ShowModePage> {
  bool _rotated = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final original = widget.original;
    return AppPlatformScaffold(
      backgroundColor: scheme.inverseSurface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(AppParams.spacing8.r),
              child: Row(
                children: [
                  AppCircleIconButton(
                    icon: AppIcons.close,
                    semanticLabel: l10n.showModeClose,
                    color: scheme.onInverseSurface,
                    borderColor: Colors.transparent,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (widget.lang != null) ...[
                    AppCircleIconButton(
                      icon: AppIcons.speaker,
                      semanticLabel: l10n.showModeSpeak,
                      color: scheme.onInverseSurface,
                      borderColor: scheme.onInverseSurface,
                      onPressed: () => ref
                          .read(speechSynthesizerProvider)
                          .speak(widget.text, lang: widget.lang!),
                    ),
                    SizedBox(width: AppParams.spacing8.w),
                  ],
                  AppCircleIconButton(
                    icon: AppIcons.rotate,
                    semanticLabel: l10n.showModeRotate,
                    color: scheme.onInverseSurface,
                    borderColor: scheme.onInverseSurface,
                    selected: _rotated,
                    onPressed: () => setState(() => _rotated = !_rotated),
                  ),
                ],
              ),
            ),
            if (widget.hint != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppParams.spacing24.w,
                ),
                child: Text(
                  widget.hint!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: scheme.onInverseSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
            Expanded(
              child: RotatedBox(
                quarterTurns: _rotated ? 2 : 0,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppParams.spacing24.w,
                      vertical: AppParams.spacing24.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.text,
                          style: context.textTheme.displaySmall?.copyWith(
                            color: scheme.onInverseSurface,
                          ),
                        ),
                        if (original != null) ...[
                          SizedBox(height: AppParams.spacing16.h),
                          Text(
                            original,
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: scheme.onInverseSurface.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

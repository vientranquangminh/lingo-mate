import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';

/// Back button, title and trailing actions of the glossary screens.
class GlossaryHeader extends StatelessWidget {
  const GlossaryHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppParams.spacing8.w,
        vertical: AppParams.spacing8.h,
      ),
      child: Row(
        children: [
          AppCircleIconButton(
            icon: AppIcons.back,
            semanticLabel: context.localization.conversationBack,
            borderColor: Colors.transparent,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          SizedBox(width: AppParams.spacing8.w),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleLarge?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

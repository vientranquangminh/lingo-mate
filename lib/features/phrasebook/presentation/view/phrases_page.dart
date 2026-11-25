import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';

/// Phrases tab; the phrasebook (T-1.9) and quick phrases (T-1.10) fill it.
class PhrasesPage extends StatelessWidget {
  const PhrasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.navPhrases)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppParams.spacing24.r),
          child: Text(
            l10n.phrasesComingSoon,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

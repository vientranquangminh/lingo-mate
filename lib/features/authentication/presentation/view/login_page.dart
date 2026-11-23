import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/text_style_ext.dart';
import '../../../../common/widgets/app_scaffold.dart';

/// TODO: This UI is for template purpose
///
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPlatformScaffold(
      body: Center(
        child: Text(
          context.localization.login,
          style: context.regularSize14BlackText,
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../gen/colors.gen.dart';
import 'app_circular_progress_indicator.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorName.blackA54,
      child: const Center(child: AppCircularProgressIndicator()),
    );
  }
}

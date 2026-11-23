import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../extensions/platform_ext.dart';
import '../../gen/colors.gen.dart';

class AppCircularProgressIndicator extends StatelessWidget {
  const AppCircularProgressIndicator({super.key, this.color = ColorName.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return CupertinoActivityIndicator(color: color, radius: 20.r);
    }
    return CircularProgressIndicator(color: color);
  }
}

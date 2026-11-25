import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/auth/auth_models.dart';
import '../extensions/build_context_ext.dart';

/// Round avatar with the user's initials on the brand-soft colour.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 48});

  final AppUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size.r,
        height: size.r,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          user.initials,
          style: context.textTheme.titleMedium?.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

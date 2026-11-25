import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/shared/models/system_member.dart';

/// Deterministic avatar for a member or the unknown identity.
class MemberAvatar extends StatelessWidget {
  /// Creates an avatar at [size] logical pixels.
  const MemberAvatar({
    super.key,
    this.member,
    this.size = 34,
    this.border = false,
  });

  final SystemMember? member;
  final double size;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: member?.color ?? const Color(0xFFE4E3DE),
      shape: BoxShape.circle,
      border: border ? Border.all(color: AppColors.paper, width: 2) : null,
    ),
    child: member == null
        ? Icon(Icons.person_outline, color: AppColors.muted, size: size * .55)
        : Text(
            member!.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * .3,
            ),
          ),
  );
}

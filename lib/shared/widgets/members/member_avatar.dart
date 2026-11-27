import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/features/members/system_member.dart';

/// Deterministic avatar for a member or the anonymous identity.
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

  static const _colors = [
    Color(0xFFB56B4D),
    Color(0xFF527C72),
    Color(0xFF786D9C),
    Color(0xFF8A704B),
    Color(0xFF486B83),
    Color(0xFF8B5D75),
  ];

  String get _initials {
    final words = member!.name.trim().split(RegExp(r'\s+'));
    final value = words
        .take(2)
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();
    return value.isEmpty ? '?' : value;
  }

  Color get _color => _colors[member!.id.hashCode.abs() % _colors.length];

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: member == null ? const Color(0xFFE4E3DE) : _color,
      shape: BoxShape.circle,
      border: border ? Border.all(color: AppColors.paper, width: 2) : null,
    ),
    child: member == null
        ? Icon(Icons.person_outline, color: AppColors.muted, size: size * .55)
        : Text(
            _initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * .3,
            ),
          ),
  );
}

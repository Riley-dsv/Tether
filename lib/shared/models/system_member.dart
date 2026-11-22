import 'package:material_ui/material_ui.dart';

@immutable
class SystemMember {
  const SystemMember(this.id, this.name, this.initials, this.color);

  factory SystemMember.fromStorage({required String id, required String name}) {
    const colors = [
      Color(0xFFB56B4D),
      Color(0xFF527C72),
      Color(0xFF786D9C),
      Color(0xFF8A704B),
      Color(0xFF486B83),
      Color(0xFF8B5D75),
    ];
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .take(2)
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase())
        .join();
    return SystemMember(
      id,
      name,
      initials.isEmpty ? '?' : initials,
      colors[id.hashCode.abs() % colors.length],
    );
  }

  final String id;
  final String name;
  final String initials;
  final Color color;
}

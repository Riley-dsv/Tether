import 'package:material_ui/material_ui.dart';

@immutable
/// An optional internal identity used for attribution and targeting.
///
/// Absence of a [SystemMember] represents an unknown or unspecified author;
/// the application never persists a synthetic “Unknown” member.
class SystemMember {
  /// Creates an already-derived presentation model.
  const SystemMember(this.id, this.name, this.initials, this.color);

  /// Builds a member from persisted identity fields.
  ///
  /// Initials and color are deterministic presentation values. They are not
  /// stored identity attributes and must not be used for authorization.
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

  /// Stable database identifier.
  final String id;

  /// User-selected display name.
  final String name;

  /// At most two initials derived from [name].
  final String initials;

  /// Deterministic avatar color derived from [id].
  final Color color;
}

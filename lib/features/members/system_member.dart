/// An optional internal identity used for attribution and targeting.
///
/// Absence of a [SystemMember] represents an unknown or unspecified author;
/// the application never persists a synthetic “Unknown” member.
class SystemMember {
  /// Creates a member with its stable [id] and user-selected [name].
  const SystemMember({required this.id, required this.name});

  /// Builds a member from persisted identity fields.
  ///
  factory SystemMember.fromStorage({
    required String id,
    required String name,
  }) => SystemMember(id: id, name: name);

  /// Stable database identifier.
  final String id;

  /// User-selected display name.
  final String name;
}

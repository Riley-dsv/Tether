/// An optional internal identity used for attribution and targeting.
///
/// Absence of a [SystemMember] represents an unknown or unspecified author;
/// the application never persists a synthetic “Unknown” member.
class SystemMember {
  /// Creates a member with its stable [id] and user-selected [name].
  const SystemMember({
    required this.id,
    required this.name,
    this.hasPin = false,
  });

  /// Builds a member from persisted identity fields.
  ///
  factory SystemMember.fromStorage({
    required String id,
    required String name,
    bool hasPin = false,
  }) => SystemMember(id: id, name: name, hasPin: hasPin);

  /// Stable database identifier.
  final String id;

  /// User-selected display name.
  final String name;

  /// Whether selecting this identity requires PIN verification.
  final bool hasPin;
}

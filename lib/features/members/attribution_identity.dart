import 'package:note_app/features/members/system_member.dart';

/// Attribution used by content creation, independent from authentication.
sealed class AttributionIdentity {
  const AttributionIdentity();

  /// A concrete member only when this attribution can own credentials.
  SystemMember? get authenticatableMember;
}

/// Anonymous attribution. It is never a persisted member or credential owner.
final class UnknownAttribution extends AttributionIdentity {
  const UnknownAttribution();

  @override
  SystemMember? get authenticatableMember => null;
}

/// Attribution shared by multiple people without authenticating any of them.
final class CollectiveAttribution extends AttributionIdentity {
  CollectiveAttribution(Iterable<SystemMember> members)
    : members = List.unmodifiable(members);

  final List<SystemMember> members;

  @override
  SystemMember? get authenticatableMember => null;
}

/// Attribution tied to one credential-owning member.
final class MemberAttribution extends AttributionIdentity {
  const MemberAttribution(this.member);

  final SystemMember member;

  @override
  SystemMember get authenticatableMember => member;
}

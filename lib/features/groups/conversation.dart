import 'package:note_app/shared/models/system_member.dart';

/// A persistent communication space and its active membership projection.
///
/// [members] excludes archived profiles, while historical messages retain
/// their original attribution through the database relationship.
class Conversation {
  /// Creates an immutable conversation projection.
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.members,
    required this.unreadCount,
    this.isGeneral = false,
    this.lastMessage,
  });

  /// Stable conversation identifier.
  final String id;

  /// Human-readable title.
  final String title;

  /// UTC creation instant as persisted by the repository.
  final DateTime createdAt;

  /// Active members allowed to participate in this space.
  final List<SystemMember> members;

  /// Messages not acknowledged by the current viewer.
  final int unreadCount;

  /// Whether this is the unique space containing every active member.
  final bool isGeneral;

  /// Privacy-safe preview, or `null` when the conversation has no messages.
  final String? lastMessage;
}

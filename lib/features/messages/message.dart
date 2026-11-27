import 'package:note_app/features/members/system_member.dart';

/// Audience classification derived from a message's explicit recipients.
///
/// `shared` has no explicit recipients, `private` has one, and `group` has
/// more than one. Conversation membership remains an additional access check.
enum MessageVisibility { private, group, shared }

/// The latest visible revision of a logical message.
///
/// A [Message] is a read model. Editing creates another persisted revision;
/// it never mutates this instance or overwrites prior history.
class Message {
  /// Creates an immutable message projection.
  const Message({
    required this.id,
    required this.revisionId,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.revision,
    required this.isPinned,
    required this.seenBy,
    required this.seenByNames,
    required this.visibility,
    required this.recipientIds,
    required this.recipientNames,
    this.sourceMessageId,
    this.sourceConversationTitle,
    this.editedAt,
  });

  /// Stable logical message identifier shared by all revisions.
  final String id;

  /// Database identifier of the projected revision.
  final int revisionId;

  /// Attributed author, or `null` for unknown/collective attribution.
  final SystemMember? author;

  /// Decrypted content of this revision.
  final String text;

  /// Creation time of the logical message.
  final DateTime createdAt;

  /// Recording time of the latest edit, if this is not revision one.
  final DateTime? editedAt;

  /// Monotonically increasing revision number, starting at one.
  final int revision;

  /// Whether the logical message is currently pinned.
  final bool isPinned;

  /// Member identifiers that acknowledged the message.
  final Set<String> seenBy;

  /// Display names corresponding to [seenBy].
  final List<String> seenByNames;

  /// Effective audience classification.
  final MessageVisibility visibility;

  /// Explicit audience identifiers; empty for shared messages.
  final Set<String> recipientIds;

  /// Display names corresponding to [recipientIds].
  final List<String> recipientNames;

  /// Logical source message when this information was transferred.
  final String? sourceMessageId;

  /// Display title of the source space, when available.
  final String? sourceConversationTitle;

  /// Convenience identifier that preserves nullable attribution semantics.
  String? get authorId => author?.id;

  /// Whether this projection has at least one edit revision.
  bool get isEdited => revision > 1;

  /// Compact local-time label for the current UI.
  String get time {
    final now = DateTime.now();
    final local = createdAt.toLocal();
    if (now.difference(local).inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

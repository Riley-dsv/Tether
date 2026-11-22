import 'package:note_app/shared/models/system_member.dart';

enum MessageVisibility { private, group, shared }

class Message {
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

  final String id;
  final int revisionId;
  final SystemMember? author;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final int revision;
  final bool isPinned;
  final Set<String> seenBy;
  final List<String> seenByNames;
  final MessageVisibility visibility;
  final Set<String> recipientIds;
  final List<String> recipientNames;
  final String? sourceMessageId;
  final String? sourceConversationTitle;

  String? get authorId => author?.id;
  bool get isEdited => revision > 1;

  String get time {
    final now = DateTime.now();
    final local = createdAt.toLocal();
    if (now.difference(local).inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

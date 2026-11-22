import 'package:note_app/shared/models/system_member.dart';

class SystemEvent {
  const SystemEvent({
    required this.id,
    required this.type,
    required this.summary,
    required this.isTechnical,
    required this.createdAt,
    required this.actor,
    required this.conversationTitle,
    this.relatedTaskId,
  });

  final int id;
  final String type;
  final String summary;
  final bool isTechnical;
  final DateTime createdAt;
  final SystemMember? actor;
  final String? conversationTitle;
  final String? relatedTaskId;
}

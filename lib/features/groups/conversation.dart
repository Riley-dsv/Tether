import 'package:note_app/shared/models/system_member.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.members,
    required this.unreadCount,
    this.isGeneral = false,
    this.lastMessage,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final List<SystemMember> members;
  final int unreadCount;
  final bool isGeneral;
  final String? lastMessage;
}

import 'package:note_app/shared/models/system_member.dart';

enum HandoverPriority { low, normal, high, urgent }

class HandoverItem {
  const HandoverItem({required this.description, required this.isCompleted});

  final String description;
  final bool isCompleted;
}

class Handover {
  const Handover({
    required this.id,
    required this.summary,
    required this.priority,
    required this.context,
    required this.createdAt,
    required this.expiresAt,
    required this.author,
    required this.recipients,
    required this.items,
    required this.readBy,
  });

  final String id;
  final String summary;
  final HandoverPriority priority;
  final String? context;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final SystemMember? author;
  final List<SystemMember> recipients;
  final List<HandoverItem> items;
  final Set<String> readBy;

  bool get isExpired => expiresAt?.isBefore(DateTime.now()) ?? false;
}

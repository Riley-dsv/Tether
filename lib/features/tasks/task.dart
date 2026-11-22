import 'package:note_app/shared/models/system_member.dart';

enum TaskStatus { todo, inProgress, done }

enum TaskAssignment { anyone, specific }

class WorkspaceTask {
  const WorkspaceTask({
    required this.id,
    required this.title,
    required this.status,
    required this.assignment,
    required this.assignees,
    required this.createdAt,
    required this.updatedAt,
    this.deadline,
    this.reminderAt,
    this.author,
  });

  final String id;
  final String title;
  final TaskStatus status;
  final TaskAssignment assignment;
  final List<SystemMember> assignees;
  final DateTime? deadline;
  final DateTime? reminderAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SystemMember? author;
}

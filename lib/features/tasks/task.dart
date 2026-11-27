import 'package:note_app/features/members/system_member.dart';

/// Lifecycle state of a collaborative task.
enum TaskStatus { todo, inProgress, done }

/// Assignment policy for a task.
///
/// [TaskAssignment.anyone] intentionally has no required owner, while
/// [TaskAssignment.specific] requires at least one assignee.
enum TaskAssignment { anyone, specific }

/// Persisted collaborative task and optional reminder information.
class WorkspaceTask {
  /// Creates an immutable task projection.
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

  /// Stable task identifier.
  final String id;

  /// User-provided task description.
  final String title;

  /// Current lifecycle state.
  final TaskStatus status;

  /// Assignment policy governing [assignees].
  final TaskAssignment assignment;

  /// Explicit assignees; empty when anyone may act.
  final List<SystemMember> assignees;

  /// Optional completion deadline.
  final DateTime? deadline;

  /// Optional earlier notification/reminder instant.
  final DateTime? reminderAt;

  /// Creation instant.
  final DateTime createdAt;

  /// Most recent status update instant.
  final DateTime updatedAt;

  /// Attributed creator, or `null` for unknown attribution.
  final SystemMember? author;
}

import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/features/tasks/task.dart';
import 'package:note_app/shared/models/system_member.dart';

/// Persistence contract for collaborative tasks and reminders.
abstract interface class TaskStore {
  /// Lists tasks in a conversation visible to [viewerId].
  ///
  /// A `null` viewer receives an empty result rather than attributed data.
  Future<List<WorkspaceTask>> list({
    required String conversationId,
    String? viewerId,
  });

  /// Creates a task and its optional assignee set atomically.
  ///
  /// [TaskAssignment.specific] requires at least one assignee;
  /// [TaskAssignment.anyone] deliberately permits an empty set.
  Future<void> create({
    required String conversationId,
    required String title,
    required TaskAssignment assignment,
    required Set<String> assigneeIds,
    required TaskStatus status,
    String? authorId,
    DateTime? deadline,
    DateTime? reminderAt,
  });

  /// Appends a meaningful task status transition to the system log.
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
    String? actorId,
  });
}

/// SQLite implementation of [TaskStore].
class TaskRepository implements TaskStore {
  /// Creates a task repository over [AppDatabase].
  TaskRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  int _sequence = 0;

  @override
  Future<List<WorkspaceTask>> list({
    required String conversationId,
    String? viewerId,
  }) async {
    if (viewerId == null) return const [];
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT task.*, author.display_name AS author_name
      FROM tasks task
      LEFT JOIN members author ON author.id = task.author_id
      WHERE task.conversation_id = ? AND EXISTS (
        SELECT 1 FROM conversation_members access
        WHERE access.conversation_id = task.conversation_id
          AND access.member_id = ?
      )
      ORDER BY CASE task.status WHEN 'todo' THEN 0 WHEN 'inProgress' THEN 1 ELSE 2 END,
        task.deadline IS NULL, task.deadline, task.created_at DESC
    ''',
      [conversationId, viewerId],
    );
    final tasks = <WorkspaceTask>[];
    for (final row in rows) {
      final assignees = await db.rawQuery(
        '''
        SELECT member.id, member.display_name FROM task_assignees assignee
        JOIN members member ON member.id = assignee.member_id
        WHERE assignee.task_id = ? ORDER BY member.display_name COLLATE NOCASE
      ''',
        [row['id']],
      );
      tasks.add(
        WorkspaceTask(
          id: row['id'] as String,
          title: row['title'] as String,
          status: TaskStatus.values.byName(row['status'] as String),
          assignment: TaskAssignment.values.byName(
            row['assignment_mode'] as String,
          ),
          assignees: assignees
              .map(
                (member) => SystemMember.fromStorage(
                  id: member['id'] as String,
                  name: member['display_name'] as String,
                ),
              )
              .toList(growable: false),
          deadline: _date(row['deadline']),
          reminderAt: _date(row['reminder_at']),
          createdAt: DateTime.parse(row['created_at'] as String),
          updatedAt: DateTime.parse(row['updated_at'] as String),
          author: row['author_id'] == null
              ? null
              : SystemMember.fromStorage(
                  id: row['author_id'] as String,
                  name: row['author_name'] as String,
                ),
        ),
      );
    }
    return tasks;
  }

  @override
  Future<void> create({
    required String conversationId,
    required String title,
    required TaskAssignment assignment,
    required Set<String> assigneeIds,
    required TaskStatus status,
    String? authorId,
    DateTime? deadline,
    DateTime? reminderAt,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title');
    if (assignment == TaskAssignment.specific && assigneeIds.isEmpty) {
      throw ArgumentError('Specific tasks require at least one assignee');
    }
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    final id = 'task_${now.microsecondsSinceEpoch}_${_sequence++}';
    await db.transaction((txn) async {
      final memberIds = {...assigneeIds, ?authorId};
      for (final memberId in memberIds) {
        final member = await txn.query(
          'conversation_members',
          where: 'conversation_id = ? AND member_id = ?',
          whereArgs: [conversationId, memberId],
          limit: 1,
        );
        if (member.isEmpty) {
          throw StateError('Task member is not in this conversation');
        }
      }
      await txn.insert('tasks', {
        'id': id,
        'conversation_id': conversationId,
        'author_id': authorId,
        'title': cleanTitle,
        'status': status.name,
        'assignment_mode': assignment.name,
        'deadline': deadline?.toUtc().toIso8601String(),
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      if (assignment == TaskAssignment.specific) {
        for (final memberId in assigneeIds) {
          await txn.insert('task_assignees', {
            'task_id': id,
            'member_id': memberId,
          });
        }
      }
      await SystemLogRepository.record(
        txn,
        type: 'task_created',
        summary: 'created task “$cleanTitle”',
        conversationId: conversationId,
        actorId: authorId,
        relatedTaskId: id,
      );
    });
  }

  @override
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
    String? actorId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'tasks',
        columns: ['conversation_id', 'title'],
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Task no longer exists');
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'tasks',
        {'status': status.name, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      final title = rows.first['title'] as String;
      await SystemLogRepository.record(
        txn,
        type: status == TaskStatus.done
            ? 'task_completed'
            : 'task_status_changed',
        summary: status == TaskStatus.done
            ? 'completed task “$title”'
            : 'changed task “$title” to ${_statusLabel(status)}',
        conversationId: rows.first['conversation_id'] as String,
        actorId: actorId,
        relatedTaskId: taskId,
      );
    });
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
  static String _statusLabel(TaskStatus status) => switch (status) {
    TaskStatus.todo => 'To do',
    TaskStatus.inProgress => 'In progress',
    TaskStatus.done => 'Done',
  };
}

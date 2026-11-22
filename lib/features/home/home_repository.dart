import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/home/home_summary.dart';

abstract interface class HomeStore {
  Future<HomeSummary> summary({required String? viewerId});
}

class HomeRepository implements HomeStore {
  HomeRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  @override
  Future<HomeSummary> summary({required String? viewerId}) async {
    if (viewerId == null) return const HomeSummary.empty();
    final db = await _appDatabase.database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toUtc();
    final tomorrowStart = DateTime(now.year, now.month, now.day + 1).toUtc();
    final results = await Future.wait([
      db.rawQuery(
        '''
        SELECT COUNT(*) AS total FROM message_revisions revision
        JOIN message_entities message ON message.id = revision.logical_id
        JOIN conversation_members access ON access.conversation_id = message.conversation_id
        WHERE access.member_id = ? AND revision.deleted_at IS NULL
          AND revision.revision = (SELECT MAX(latest.revision) FROM message_revisions latest WHERE latest.logical_id = revision.logical_id)
          AND NOT EXISTS (SELECT 1 FROM message_receipts receipt WHERE receipt.logical_id = message.id AND receipt.member_id = ?)
          AND (message.visibility = 'shared' OR revision.author_id = ? OR EXISTS (SELECT 1 FROM message_recipients recipient WHERE recipient.logical_id = message.id AND recipient.member_id = ?))
      ''',
        [viewerId, viewerId, viewerId, viewerId],
      ),
      db.rawQuery(
        '''
        SELECT COUNT(*) AS total FROM handovers handover
        JOIN handover_recipients recipient ON recipient.handover_id = handover.id
        WHERE recipient.member_id = ? AND handover.priority IN ('high', 'urgent')
          AND (handover.expires_at IS NULL OR handover.expires_at > ?)
          AND NOT EXISTS (SELECT 1 FROM handover_receipts receipt WHERE receipt.handover_id = handover.id AND receipt.member_id = ?)
      ''',
        [viewerId, now.toUtc().toIso8601String(), viewerId],
      ),
      db.rawQuery(
        '''
        SELECT COUNT(*) AS total FROM tasks task
        JOIN conversation_members access ON access.conversation_id = task.conversation_id
        WHERE access.member_id = ? AND task.status != 'done'
          AND task.deadline >= ? AND task.deadline < ?
          AND (task.assignment_mode = 'anyone' OR EXISTS (SELECT 1 FROM task_assignees assignee WHERE assignee.task_id = task.id AND assignee.member_id = ?))
      ''',
        [
          viewerId,
          todayStart.toIso8601String(),
          tomorrowStart.toIso8601String(),
          viewerId,
        ],
      ),
      db.rawQuery(
        '''
        SELECT task.title, task.reminder_at, task.deadline FROM tasks task
        JOIN conversation_members access ON access.conversation_id = task.conversation_id
        WHERE access.member_id = ? AND task.status != 'done'
          AND (task.assignment_mode = 'anyone' OR EXISTS (SELECT 1 FROM task_assignees assignee WHERE assignee.task_id = task.id AND assignee.member_id = ?))
          AND (task.reminder_at > ? OR task.deadline > ?)
        ORDER BY CASE
          WHEN task.reminder_at > ? AND (task.deadline IS NULL OR task.reminder_at <= task.deadline) THEN task.reminder_at
          ELSE task.deadline END
        LIMIT 1
      ''',
        [
          viewerId,
          viewerId,
          now.toUtc().toIso8601String(),
          now.toUtc().toIso8601String(),
          now.toUtc().toIso8601String(),
        ],
      ),
    ]);
    final nextRow = results[3].isEmpty ? null : results[3].first;
    HomeNextItem? nextItem;
    if (nextRow != null) {
      final reminder = _date(nextRow['reminder_at']);
      final deadline = _date(nextRow['deadline']);
      final useReminder =
          reminder != null &&
          reminder.isAfter(now.toUtc()) &&
          (deadline == null || !reminder.isAfter(deadline));
      final at = useReminder ? reminder : deadline;
      if (at != null) {
        nextItem = HomeNextItem(
          title: nextRow['title'] as String,
          at: at,
          kind: useReminder
              ? HomeNextItemKind.reminder
              : HomeNextItemKind.deadline,
        );
      }
    }
    return HomeSummary(
      unreadMessages: _count(results[0]),
      importantHandovers: _count(results[1]),
      tasksToday: _count(results[2]),
      nextItem: nextItem,
    );
  }

  static int _count(List<Map<String, Object?>> rows) =>
      (rows.single['total'] as num).toInt();
  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

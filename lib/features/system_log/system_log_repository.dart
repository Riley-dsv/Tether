import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/system_log/system_event.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:sqflite/sqflite.dart';

/// Query contract for the cross-cutting human-readable activity feed.
abstract interface class SystemLogStore {
  /// Lists newest events visible to [viewerId].
  ///
  /// Related private objects apply their own visibility rules. Technical events
  /// remain hidden unless [includeTechnical] is true.
  Future<List<SystemEvent>> list({
    String? viewerId,
    bool includeTechnical = false,
    int limit = 250,
  });
}

/// SQLite implementation of [SystemLogStore].
class SystemLogRepository implements SystemLogStore {
  /// Creates a system-log repository over [AppDatabase].
  SystemLogRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  /// Inserts an event using an existing database executor or transaction.
  ///
  /// Repositories call this inside their mutation transaction so domain state
  /// and its explanatory event cannot diverge.
  static Future<void> record(
    DatabaseExecutor db, {
    required String type,
    required String summary,
    String? conversationId,
    String? actorId,
    String? relatedMessageId,
    String? relatedHandoverId,
    String? relatedTaskId,
    bool isTechnical = false,
  }) => db.insert('system_events', {
    'conversation_id': conversationId,
    'actor_id': actorId,
    'event_type': type,
    'summary': summary,
    'is_technical': isTechnical ? 1 : 0,
    'related_message_id': relatedMessageId,
    'related_handover_id': relatedHandoverId,
    'related_task_id': relatedTaskId,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  @override
  Future<List<SystemEvent>> list({
    String? viewerId,
    bool includeTechnical = false,
    int limit = 250,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT event.*, actor.display_name AS actor_name,
        conversation.title AS conversation_title
      FROM system_events event
      LEFT JOIN members actor ON actor.id = event.actor_id
      LEFT JOIN conversations conversation ON conversation.id = event.conversation_id
      WHERE (? = 1 OR event.is_technical = 0)
        AND (
          (event.related_message_id IS NULL
            AND event.related_handover_id IS NULL
            AND event.related_task_id IS NULL
            AND (
              event.conversation_id IS NULL
              OR EXISTS (
                SELECT 1 FROM conversations event_conversation
                WHERE event_conversation.id = event.conversation_id AND (
                  event_conversation.scope = 'general'
                  OR EXISTS (
                    SELECT 1 FROM conversation_members event_access
                    WHERE event_access.conversation_id = event_conversation.id
                      AND event_access.member_id = ?
                  )
                )
              )
            ))
          OR EXISTS (
            SELECT 1 FROM message_entities message
            LEFT JOIN message_revisions revision ON revision.logical_id = message.id
            WHERE message.id = event.related_message_id AND (
              message.visibility = 'shared' OR revision.author_id = ? OR EXISTS (
                SELECT 1 FROM message_recipients recipient
                WHERE recipient.logical_id = message.id AND recipient.member_id = ?
              )
            )
          )
          OR EXISTS (
            SELECT 1 FROM handovers handover
            WHERE handover.id = event.related_handover_id AND (
              handover.author_id = ? OR EXISTS (
                SELECT 1 FROM handover_recipients recipient
                WHERE recipient.handover_id = handover.id AND recipient.member_id = ?
              )
            )
          )
          OR EXISTS (
            SELECT 1 FROM tasks task
            JOIN conversation_members access
              ON access.conversation_id = task.conversation_id
            WHERE task.id = event.related_task_id AND access.member_id = ?
          )
        )
      ORDER BY event.created_at DESC, event.id DESC
      LIMIT ?
    ''',
      [
        includeTechnical ? 1 : 0,
        viewerId,
        viewerId,
        viewerId,
        viewerId,
        viewerId,
        viewerId,
        limit,
      ],
    );
    return rows
        .map(
          (row) => SystemEvent(
            id: row['id'] as int,
            type: row['event_type'] as String,
            summary: row['summary'] as String,
            isTechnical: row['is_technical'] == 1,
            createdAt: DateTime.parse(row['created_at'] as String),
            actor: row['actor_id'] == null
                ? null
                : SystemMember.fromStorage(
                    id: row['actor_id'] as String,
                    name: row['actor_name'] as String,
                  ),
            conversationTitle: row['conversation_title'] as String?,
            relatedTaskId: row['related_task_id'] as String?,
          ),
        )
        .toList(growable: false);
  }
}

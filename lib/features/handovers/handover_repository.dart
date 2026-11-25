import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/handovers/handover.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/shared/models/system_member.dart';
import 'package:sqflite/sqflite.dart';

/// Persistence contract for structured, targeted handovers.
abstract interface class HandoverStore {
  /// Lists handovers visible to [viewerId] in one conversation.
  ///
  /// Unknown viewers receive no handovers because recipients are explicit.
  Future<List<Handover>> list({
    required String conversationId,
    String? viewerId,
  });

  /// Creates a handover and its recipients/items atomically.
  ///
  /// Every recipient and non-null author must belong to the conversation.
  Future<void> create({
    required String conversationId,
    required String summary,
    required Set<String> recipientIds,
    required HandoverPriority priority,
    required List<HandoverItem> items,
    String? context,
    DateTime? expiresAt,
    String? authorId,
  });

  /// Records an idempotent read receipt for a valid recipient.
  Future<void> markRead({required String handoverId, required String memberId});
}

/// SQLite implementation of [HandoverStore].
class HandoverRepository implements HandoverStore {
  /// Creates a handover repository over [AppDatabase].
  HandoverRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  int _sequence = 0;

  @override
  Future<List<Handover>> list({
    required String conversationId,
    String? viewerId,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT h.*, author.display_name AS author_name,
        GROUP_CONCAT(DISTINCT receipt.member_id) AS read_by
      FROM handovers h
      LEFT JOIN members author ON author.id = h.author_id
      LEFT JOIN handover_receipts receipt ON receipt.handover_id = h.id
      WHERE h.conversation_id = ?
        AND (? IS NOT NULL AND (h.author_id = ? OR EXISTS (
          SELECT 1 FROM handover_recipients access
          WHERE access.handover_id = h.id AND access.member_id = ?
        )))
      GROUP BY h.id
      ORDER BY h.created_at DESC
    ''',
      [conversationId, viewerId, viewerId, viewerId],
    );

    final result = <Handover>[];
    for (final row in rows) {
      final recipientRows = await db.rawQuery(
        '''
        SELECT m.id, m.display_name FROM handover_recipients recipient
        JOIN members m ON m.id = recipient.member_id
        WHERE recipient.handover_id = ? ORDER BY m.display_name COLLATE NOCASE
      ''',
        [row['id']],
      );
      final itemRows = await db.query(
        'handover_items',
        where: 'handover_id = ?',
        whereArgs: [row['id']],
        orderBy: 'sort_order, id',
      );
      result.add(
        Handover(
          id: row['id'] as String,
          summary: row['summary'] as String,
          priority: HandoverPriority.values.byName(row['priority'] as String),
          context: row['context'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
          expiresAt: row['expires_at'] == null
              ? null
              : DateTime.parse(row['expires_at'] as String),
          author: row['author_id'] == null
              ? null
              : SystemMember.fromStorage(
                  id: row['author_id'] as String,
                  name: row['author_name'] as String,
                ),
          recipients: recipientRows
              .map(
                (member) => SystemMember.fromStorage(
                  id: member['id'] as String,
                  name: member['display_name'] as String,
                ),
              )
              .toList(growable: false),
          items: itemRows
              .map(
                (item) => HandoverItem(
                  description: item['description'] as String,
                  isCompleted: item['is_completed'] == 1,
                ),
              )
              .toList(growable: false),
          readBy:
              (row['read_by'] as String?)
                  ?.split(',')
                  .where((id) => id.isNotEmpty)
                  .toSet() ??
              const {},
        ),
      );
    }
    return result;
  }

  @override
  Future<void> create({
    required String conversationId,
    required String summary,
    required Set<String> recipientIds,
    required HandoverPriority priority,
    required List<HandoverItem> items,
    String? context,
    DateTime? expiresAt,
    String? authorId,
  }) async {
    final cleanSummary = summary.trim();
    if (cleanSummary.isEmpty) throw ArgumentError.value(summary, 'summary');
    if (recipientIds.isEmpty) {
      throw ArgumentError('At least one recipient is required');
    }
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    final id = 'handover_${now.microsecondsSinceEpoch}_${_sequence++}';
    await db.transaction((txn) async {
      if (authorId != null) {
        await _requireMember(txn, conversationId, authorId);
      }
      for (final recipientId in recipientIds) {
        await _requireMember(txn, conversationId, recipientId);
      }
      await txn.insert('handovers', {
        'id': id,
        'conversation_id': conversationId,
        'author_id': authorId,
        'summary': cleanSummary,
        'priority': priority.name,
        'context': context?.trim().isEmpty == true ? null : context?.trim(),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'created_at': now.toIso8601String(),
      });
      for (final recipientId in recipientIds) {
        await txn.insert('handover_recipients', {
          'handover_id': id,
          'member_id': recipientId,
        });
      }
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        if (item.description.trim().isEmpty) continue;
        await txn.insert('handover_items', {
          'handover_id': id,
          'description': item.description.trim(),
          'is_completed': item.isCompleted ? 1 : 0,
          'sort_order': index,
        });
      }
      if (authorId != null) {
        await txn.insert('handover_receipts', {
          'handover_id': id,
          'member_id': authorId,
          'read_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await SystemLogRepository.record(
        txn,
        type: 'handover_created',
        summary: 'created a handover',
        conversationId: conversationId,
        actorId: authorId,
        relatedHandoverId: id,
      );
      for (final item in items.where(
        (item) => item.description.trim().isNotEmpty,
      )) {
        await SystemLogRepository.record(
          txn,
          type: item.isCompleted ? 'task_completed' : 'task_created',
          summary: item.isCompleted
              ? 'completed task “${item.description.trim()}”'
              : 'created task “${item.description.trim()}”',
          conversationId: conversationId,
          actorId: authorId,
          relatedHandoverId: id,
        );
      }
    });
  }

  @override
  Future<void> markRead({
    required String handoverId,
    required String memberId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final allowed = await txn.rawQuery(
        '''
        SELECT 1 FROM handovers h WHERE h.id = ? AND (
          h.author_id = ? OR EXISTS (
            SELECT 1 FROM handover_recipients recipient
            WHERE recipient.handover_id = h.id AND recipient.member_id = ?
          )
        ) LIMIT 1
      ''',
        [handoverId, memberId, memberId],
      );
      if (allowed.isEmpty) throw StateError('Member cannot read this handover');
      final inserted = await txn.insert('handover_receipts', {
        'handover_id': handoverId,
        'member_id': memberId,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (inserted > 0) {
        final handover = await txn.query(
          'handovers',
          columns: ['conversation_id'],
          where: 'id = ?',
          whereArgs: [handoverId],
          limit: 1,
        );
        await SystemLogRepository.record(
          txn,
          type: 'handover_read',
          summary: 'read a handover',
          conversationId: handover.single['conversation_id'] as String,
          actorId: memberId,
          relatedHandoverId: handoverId,
        );
      }
    });
  }

  static Future<void> _requireMember(
    DatabaseExecutor db,
    String conversationId,
    String memberId,
  ) async {
    final rows = await db.rawQuery(
      'SELECT 1 FROM conversation_members WHERE conversation_id = ? AND member_id = ? LIMIT 1',
      [conversationId, memberId],
    );
    if (rows.isEmpty) {
      throw StateError('Member does not belong to this conversation');
    }
  }
}

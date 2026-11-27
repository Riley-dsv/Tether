import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/conversation.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Persistence contract for conversations and their membership.
abstract interface class WorkspaceStore {
  /// Lists spaces and viewer-specific unread counts.
  ///
  /// A `null` [viewerId] yields no attributed unread count.
  Future<List<Conversation>> conversations({String? viewerId});

  /// Creates a persistent group whose initial membership is [memberIds].
  Future<Conversation> createConversation({
    required String title,
    required Set<String> memberIds,
  });

  /// Adds an active member to a conversation idempotently.
  Future<void> addMemberToConversation({
    required String conversationId,
    required String memberId,
  });
}

/// SQLite implementation of [WorkspaceStore].
///
/// Membership changes are transactional with their system log events. The
/// unique general space is managed as a database invariant.
class WorkspaceRepository implements WorkspaceStore {
  /// Creates a workspace repository over [AppDatabase].
  WorkspaceRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  int _sequence = 0;

  @override
  Future<List<Conversation>> conversations({String? viewerId}) async {
    final db = await _appDatabase.database;
    final results = await Future.wait([
      db.rawQuery(
        '''
      SELECT c.*,
        (SELECT CASE
            WHEN r.encryption_version > 0 THEN 'Encrypted message'
            ELSE r.content
          END FROM message_revisions r
          WHERE r.conversation_id = c.id
            AND r.deleted_at IS NULL
            AND r.revision = (SELECT MAX(r2.revision) FROM message_revisions r2 WHERE r2.logical_id = r.logical_id)
          ORDER BY r.created_at DESC LIMIT 1) AS last_message,
        CASE WHEN ? IS NULL THEN 0 ELSE (
          SELECT COUNT(*) FROM message_revisions unread
          JOIN message_entities visible ON visible.id = unread.logical_id
          WHERE unread.conversation_id = c.id
            AND unread.deleted_at IS NULL
            AND unread.revision = (
              SELECT MAX(latest.revision) FROM message_revisions latest
              WHERE latest.logical_id = unread.logical_id
            )
            AND NOT EXISTS (
              SELECT 1 FROM message_receipts receipt
              WHERE receipt.logical_id = unread.logical_id
                AND receipt.member_id = ?
            )
            AND (
              visible.visibility = 'shared' OR unread.author_id = ? OR EXISTS (
                SELECT 1 FROM message_recipients target
                WHERE target.logical_id = unread.logical_id
                  AND target.member_id = ?
              )
            )
        ) END AS unread_count
      FROM conversations c
      ORDER BY CASE c.scope WHEN 'general' THEN 0 ELSE 1 END, c.created_at DESC
    ''',
        [viewerId, viewerId, viewerId, viewerId],
      ),
      db.rawQuery('''
        SELECT cm.conversation_id, m.id, m.display_name, m.pin_hash
        FROM conversation_members cm
        JOIN members m ON m.id = cm.member_id AND m.deleted_at IS NULL
        ORDER BY cm.conversation_id, m.display_name COLLATE NOCASE
      '''),
    ]);
    final conversationRows = results[0];
    final membershipRows = results[1];
    final membersByConversation = <String, List<SystemMember>>{};
    for (final row in membershipRows) {
      membersByConversation
          .putIfAbsent(row['conversation_id'] as String, () => [])
          .add(
            SystemMember.fromStorage(
              id: row['id'] as String,
              name: row['display_name'] as String,
              hasPin: row['pin_hash'] != null,
            ),
          );
    }
    return conversationRows
        .map(
          (row) => Conversation(
            id: row['id'] as String,
            title: row['title'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            lastMessage: row['last_message'] as String?,
            unreadCount: row['unread_count'] as int,
            isGeneral: row['scope'] == 'general',
            members: List.unmodifiable(
              membersByConversation[row['id'] as String] ?? const [],
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Conversation> createConversation({
    required String title,
    required Set<String> memberIds,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title');
    final db = await _appDatabase.database;
    final id = _newId('conversation');
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('conversations', {
        'id': id,
        'title': cleanTitle,
        'created_at': now,
        'scope': 'group',
      });
      for (final memberId in memberIds) {
        await txn.insert('conversation_members', {
          'conversation_id': id,
          'member_id': memberId,
          'joined_at': now,
        });
      }
      await SystemLogRepository.record(
        txn,
        type: 'conversation_created',
        summary: 'created space “$cleanTitle”',
        conversationId: id,
      );
    });
    return (await conversations()).firstWhere((item) => item.id == id);
  }

  @override
  Future<void> addMemberToConversation({
    required String conversationId,
    required String memberId,
  }) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.insert('conversation_members', {
        'conversation_id': conversationId,
        'member_id': memberId,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await SystemLogRepository.record(
        txn,
        type: 'conversation_member_added',
        summary: 'added a member to a space',
        conversationId: conversationId,
        actorId: memberId,
      );
    });
  }

  String _newId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${now}_${_sequence++}';
  }
}

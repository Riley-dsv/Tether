import 'package:note_app/database/app_database.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:note_app/features/groups/conversation.dart';
import 'package:note_app/shared/models/system_member.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:sqflite/sqflite.dart';

/// Persistence contract for internal identities and conversation membership.
abstract interface class WorkspaceStore {
  /// Lists active member profiles in display-name order.
  Future<List<SystemMember>> members();

  /// Creates a member and automatically joins them to the general space.
  Future<SystemMember> createMember(String displayName);

  /// Changes presentation identity without rewriting historical attribution.
  Future<SystemMember> renameMember({
    required String memberId,
    required String displayName,
  });

  /// Removes a member from active selection while retaining historical rows.
  Future<void> archiveMember(String memberId);

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
/// Member creation and membership changes are transactional with their system
/// log events. The unique general space is managed as a database invariant.
class WorkspaceRepository implements WorkspaceStore {
  /// Creates a workspace repository over [AppDatabase].
  WorkspaceRepository(this._appDatabase);

  final AppDatabase _appDatabase;
  int _sequence = 0;

  @override
  Future<List<SystemMember>> members() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'members',
      where: 'deleted_at IS NULL',
      orderBy: 'display_name COLLATE NOCASE',
    );
    return rows
        .map(
          (row) => SystemMember.fromStorage(
            id: row['id'] as String,
            name: row['display_name'] as String,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<SystemMember> renameMember({
    required String memberId,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName');
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        'members',
        {'display_name': name},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [memberId],
      );
      if (updated == 0) throw StateError('Member no longer exists');
      await SystemLogRepository.record(
        txn,
        type: 'member_renamed',
        summary: 'renamed a member profile to “$name”',
      );
    });
    return SystemMember.fromStorage(id: memberId, name: name);
  }

  @override
  Future<void> archiveMember(String memberId) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final archived = await txn.update(
        'members',
        {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [memberId],
      );
      if (archived == 0) throw StateError('Member no longer exists');
      await SystemLogRepository.record(
        txn,
        type: 'member_archived',
        summary: 'removed a member profile',
      );
    });
  }

  @override
  Future<SystemMember> createMember(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName');
    final db = await _appDatabase.database;
    final id = _newId('member');
    await db.transaction((txn) async {
      await txn.insert('members', {
        'id': id,
        'display_name': name,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await txn.insert('conversation_members', {
        'conversation_id': MessageTables.generalConversationId,
        'member_id': id,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });
      await SystemLogRepository.record(
        txn,
        type: 'member_created',
        summary: 'created member profile “$name”',
      );
    });
    return SystemMember.fromStorage(id: id, name: name);
  }

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
        SELECT cm.conversation_id, m.id, m.display_name
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

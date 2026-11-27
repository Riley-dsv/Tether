import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_cipher.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:sqflite/sqflite.dart';

/// One immutable entry in a logical message's revision history.
class MessageRevision {
  /// Creates a decrypted revision projection.
  const MessageRevision({
    required this.revision,
    required this.content,
    required this.recordedAt,
    required this.recordedById,
    required this.isDeletion,
  });

  /// Monotonic logical revision number.
  final int revision;

  /// Decrypted body, empty for a deletion revision.
  final String content;

  /// Time at which this revision was appended.
  final DateTime recordedAt;

  /// Member responsible for the revision, or unknown.
  final String? recordedById;

  /// Whether this revision is the deletion tombstone.
  final bool isDeletion;
}

/// Stable keyset-pagination boundary for message history.
class MessageCursor {
  /// Creates a cursor from the final item of a page.
  const MessageCursor({required this.createdAt, required this.revisionId});

  /// Logical message creation time used as the primary ordering key.
  final DateTime createdAt;

  /// Revision row ID used to make equal timestamps deterministic.
  final int revisionId;
}

/// Persistence contract for encrypted, revisioned messages.
abstract interface class MessageStore {
  /// Opens/migrates storage and encrypts any legacy plaintext before reads.
  Future<void> prepare();

  /// Returns latest visible revisions ordered newest first.
  ///
  /// [viewerId] controls targeted visibility. Search happens after authorized
  /// rows are decrypted, and [before] provides stable keyset pagination.
  Future<List<Message>> watchSnapshot({
    required String conversationId,
    String query = '',
    bool pinnedOnly = false,
    String? viewerId,
    MessageCursor? before,
    int? limit,
  });

  /// Creates revision one and derives visibility from [recipientIds].
  ///
  /// A `null` [authorId] is valid unknown attribution. Non-null authors and all
  /// recipients must belong to the conversation.
  Future<Message> create({
    required String conversationId,
    required String content,
    String? authorId,
    Set<String> recipientIds = const {},
    String? sourceMessageId,
  });

  /// Appends an encrypted revision without overwriting previous content.
  Future<void> edit({
    required String messageId,
    required String content,
    String? editedById,
  });

  /// Appends a deletion tombstone and removes the current pin.
  Future<void> delete({required String messageId, String? deletedById});

  /// Sets the logical message's pin state independently of revisions.
  Future<void> setPinned({
    required String messageId,
    required bool pinned,
    String? actorId,
  });

  /// Adds an idempotent seen receipt for a conversation member.
  Future<void> markSeen({required String messageId, required String memberId});

  /// Counts visible, non-deleted messages not acknowledged by [memberId].
  Future<int> unreadCount({
    required String conversationId,
    required String memberId,
  });

  /// Returns all decrypted revisions newest first, including tombstones.
  Future<List<MessageRevision>> history(String messageId);
}

/// SQLite implementation of [MessageStore].
///
/// Revision bodies are encrypted independently. Legacy plaintext conversion is
/// serialized per repository instance and finishes before any message read.
class MessageRepository implements MessageStore {
  /// Creates a repository using the required application [cipher].
  MessageRepository(this._appDatabase, {required MessageCipher cipher})
    : _cipher = cipher;

  final AppDatabase _appDatabase;
  final MessageCipher _cipher;
  int _idSequence = 0;
  Future<void>? _encryptionReady;

  @override
  Future<void> prepare() => _ensureEncryption();

  @override
  Future<List<Message>> watchSnapshot({
    required String conversationId,
    String query = '',
    bool pinnedOnly = false,
    String? viewerId,
    MessageCursor? before,
    int? limit,
  }) async {
    await _ensureEncryption();
    final db = await _appDatabase.database;
    final normalizedQuery = query.trim();
    final where = <String>[
      'r.deleted_at IS NULL',
      '''(entity.visibility = 'shared' OR
          (? IS NOT NULL AND (r.author_id = ? OR EXISTS (
            SELECT 1 FROM message_recipients access
            WHERE access.logical_id = r.logical_id AND access.member_id = ?
          ))))''',
    ];
    final args = <Object?>[conversationId, viewerId, viewerId, viewerId];
    if (before != null) {
      where.add(
        '(r.created_at < ? OR (r.created_at = ? AND r.revision_id < ?))',
      );
      final timestamp = before.createdAt.toUtc().toIso8601String();
      args.addAll([timestamp, timestamp, before.revisionId]);
    }
    if (pinnedOnly) where.add('p.logical_id IS NOT NULL');

    final sqlLimit = normalizedQuery.isEmpty ? limit : null;
    if (sqlLimit != null) args.add(sqlLimit);
    final rows = await db.rawQuery('''
      WITH latest AS (
        SELECT logical_id, MAX(revision) AS revision
        FROM message_revisions
        WHERE conversation_id = ?
        GROUP BY logical_id
      )
      SELECT r.*, p.logical_id AS pinned,
        entity.visibility, entity.source_message_id,
        source_conversation.title AS source_conversation_title,
        author.display_name AS author_name,
        GROUP_CONCAT(receipts.member_id, ',') AS seen_by,
        GROUP_CONCAT(receipt_member.display_name, char(31)) AS seen_by_names,
        (SELECT GROUP_CONCAT(target.member_id, ',')
          FROM message_recipients target WHERE target.logical_id = r.logical_id) AS recipient_ids,
        (SELECT GROUP_CONCAT(target_member.display_name, char(31))
          FROM message_recipients target
          JOIN members target_member ON target_member.id = target.member_id
          WHERE target.logical_id = r.logical_id) AS recipient_names
      FROM latest
      JOIN message_revisions r
        ON r.logical_id = latest.logical_id AND r.revision = latest.revision
      JOIN message_entities entity ON entity.id = r.logical_id
      LEFT JOIN message_entities source ON source.id = entity.source_message_id
      LEFT JOIN conversations source_conversation ON source_conversation.id = source.conversation_id
      LEFT JOIN message_pins p ON p.logical_id = r.logical_id
      LEFT JOIN members author ON author.id = r.author_id
      LEFT JOIN message_receipts receipts ON receipts.logical_id = r.logical_id
      LEFT JOIN members receipt_member ON receipt_member.id = receipts.member_id
      WHERE ${where.join(' AND ')}
      GROUP BY r.revision_id
      ORDER BY r.created_at DESC, r.revision_id DESC
      ${sqlLimit == null ? '' : 'LIMIT ?'}
    ''', args);
    final messages = await Future.wait(rows.map(_messageFromRow));
    final filtered = normalizedQuery.isEmpty
        ? messages
        : messages
              .where(
                (message) => message.text.toLowerCase().contains(
                  normalizedQuery.toLowerCase(),
                ),
              )
              .toList(growable: false);
    return limit == null || filtered.length <= limit
        ? filtered
        : filtered.take(limit).toList(growable: false);
  }

  @override
  Future<Message> create({
    required String conversationId,
    required String content,
    String? authorId,
    Set<String> recipientIds = const {},
    String? sourceMessageId,
  }) async {
    await _ensureEncryption();
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) throw ArgumentError.value(content, 'content');
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    final logicalId = 'm_${now.microsecondsSinceEpoch}_${_idSequence++}';
    final encrypted = await _cipher.encrypt(
      cleanContent,
      messageId: logicalId,
      revision: 1,
    );
    await db.transaction((txn) async {
      if (authorId != null) {
        await _requireConversationMember(txn, conversationId, authorId);
      }
      for (final recipientId in recipientIds) {
        await _requireConversationMember(txn, conversationId, recipientId);
      }
      final visibility = recipientIds.isEmpty
          ? 'shared'
          : recipientIds.length == 1
          ? 'private'
          : 'group';
      await txn.insert('message_entities', {
        'id': logicalId,
        'conversation_id': conversationId,
        'created_at': now.toIso8601String(),
        'visibility': visibility,
        'source_message_id': sourceMessageId,
      });
      for (final recipientId in recipientIds) {
        await txn.insert('message_recipients', {
          'logical_id': logicalId,
          'member_id': recipientId,
        });
      }
      await txn.insert('message_revisions', {
        'logical_id': logicalId,
        'conversation_id': conversationId,
        'author_id': authorId,
        'recorded_by_id': authorId,
        ..._encryptedColumns(encrypted),
        'revision': 1,
        'created_at': now.toIso8601String(),
        'recorded_at': now.toIso8601String(),
      });
      if (authorId != null) await _markSeen(txn, logicalId, authorId, now);
      await SystemLogRepository.record(
        txn,
        type: sourceMessageId == null
            ? 'message_created'
            : 'information_transferred',
        summary: sourceMessageId == null
            ? 'posted a $visibility message'
            : 'transferred information into a space',
        conversationId: conversationId,
        actorId: authorId,
        relatedMessageId: logicalId,
      );
    });
    final effectiveViewer =
        authorId ?? (recipientIds.isEmpty ? null : recipientIds.first);
    return (await watchSnapshot(
      conversationId: conversationId,
      viewerId: effectiveViewer,
    )).firstWhere((message) => message.id == logicalId);
  }

  @override
  Future<void> edit({
    required String messageId,
    required String content,
    String? editedById,
  }) async {
    await _ensureEncryption();
    final cleanContent = content.trim();
    if (cleanContent.isEmpty) throw ArgumentError.value(content, 'content');
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final current = await _currentRevision(txn, messageId);
      if (current['deleted_at'] != null) {
        throw StateError('Cannot edit a deleted message');
      }
      if (editedById != null) {
        await _requireConversationMember(
          txn,
          current['conversation_id'] as String,
          editedById,
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final revision = (current['revision'] as int) + 1;
      final encrypted = await _cipher.encrypt(
        cleanContent,
        messageId: messageId,
        revision: revision,
      );
      await txn.insert('message_revisions', {
        'logical_id': messageId,
        'conversation_id': current['conversation_id'],
        'author_id': current['author_id'],
        'recorded_by_id': editedById,
        ..._encryptedColumns(encrypted),
        'revision': revision,
        'created_at': current['created_at'],
        'recorded_at': now,
        'supersedes_revision_id': current['revision_id'],
      });
      await SystemLogRepository.record(
        txn,
        type: 'message_edited',
        summary: 'edited a message',
        conversationId: current['conversation_id'] as String,
        actorId: editedById,
        relatedMessageId: messageId,
      );
    });
  }

  @override
  Future<void> delete({required String messageId, String? deletedById}) async {
    await _ensureEncryption();
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final current = await _currentRevision(txn, messageId);
      if (current['deleted_at'] != null) return;
      if (deletedById != null) {
        await _requireConversationMember(
          txn,
          current['conversation_id'] as String,
          deletedById,
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.insert('message_revisions', {
        'logical_id': messageId,
        'conversation_id': current['conversation_id'],
        'author_id': current['author_id'],
        'recorded_by_id': deletedById,
        'content': '',
        'revision': (current['revision'] as int) + 1,
        'created_at': current['created_at'],
        'recorded_at': now,
        'supersedes_revision_id': current['revision_id'],
        'deleted_at': now,
      });
      await txn.delete(
        'message_pins',
        where: 'logical_id = ?',
        whereArgs: [messageId],
      );
      await SystemLogRepository.record(
        txn,
        type: 'message_deleted',
        summary: 'removed a message',
        conversationId: current['conversation_id'] as String,
        actorId: deletedById,
        relatedMessageId: messageId,
      );
    });
  }

  @override
  Future<void> setPinned({
    required String messageId,
    required bool pinned,
    String? actorId,
  }) async {
    await _ensureEncryption();
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final current = await _currentRevision(txn, messageId);
      if (current['deleted_at'] != null) {
        throw StateError('Cannot pin a deleted message');
      }
      if (actorId != null) {
        await _requireConversationMember(
          txn,
          current['conversation_id'] as String,
          actorId,
        );
      }
      if (!pinned) {
        await txn.delete(
          'message_pins',
          where: 'logical_id = ?',
          whereArgs: [messageId],
        );
        await SystemLogRepository.record(
          txn,
          type: 'message_unpinned',
          summary: 'unpinned a message',
          conversationId: current['conversation_id'] as String,
          actorId: actorId,
          relatedMessageId: messageId,
        );
        return;
      }
      await txn.insert('message_pins', {
        'logical_id': messageId,
        'pinned_by': actorId,
        'pinned_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await SystemLogRepository.record(
        txn,
        type: 'message_pinned',
        summary: 'pinned a message',
        conversationId: current['conversation_id'] as String,
        actorId: actorId,
        relatedMessageId: messageId,
      );
    });
  }

  @override
  Future<void> markSeen({
    required String messageId,
    required String memberId,
  }) async {
    await _ensureEncryption();
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      final current = await _currentRevision(txn, messageId);
      if (current['deleted_at'] != null) {
        throw StateError('Cannot mark a deleted message as seen');
      }
      await _requireConversationMember(
        txn,
        current['conversation_id'] as String,
        memberId,
      );
      final inserted = await _markSeen(
        txn,
        messageId,
        memberId,
        DateTime.now().toUtc(),
      );
      if (inserted > 0) {
        await SystemLogRepository.record(
          txn,
          type: 'message_read',
          summary: 'read a message',
          conversationId: current['conversation_id'] as String,
          actorId: memberId,
          relatedMessageId: messageId,
        );
      }
    });
  }

  @override
  Future<int> unreadCount({
    required String conversationId,
    required String memberId,
  }) async {
    await _ensureEncryption();
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      WITH latest AS (
        SELECT logical_id, MAX(revision) AS revision
        FROM message_revisions WHERE conversation_id = ? GROUP BY logical_id
      )
      SELECT COUNT(*) AS count
      FROM latest
      JOIN message_revisions r ON r.logical_id = latest.logical_id AND r.revision = latest.revision
      LEFT JOIN message_receipts receipt ON receipt.logical_id = r.logical_id AND receipt.member_id = ?
      WHERE r.deleted_at IS NULL AND receipt.member_id IS NULL
        AND (r.author_id = ? OR EXISTS (
          SELECT 1 FROM message_entities visible
          WHERE visible.id = r.logical_id AND (
            visible.visibility = 'shared' OR EXISTS (
              SELECT 1 FROM message_recipients target
              WHERE target.logical_id = r.logical_id AND target.member_id = ?
            )
          )
        ))
    ''',
      [conversationId, memberId, memberId, memberId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  @override
  Future<List<MessageRevision>> history(String messageId) async {
    await _ensureEncryption();
    final db = await _appDatabase.database;
    final rows = await db.query(
      'message_revisions',
      where: 'logical_id = ?',
      whereArgs: [messageId],
      orderBy: 'revision DESC',
    );
    return Future.wait(
      rows.map((row) async {
        final isDeletion = row['deleted_at'] != null;
        return MessageRevision(
          revision: row['revision'] as int,
          content: isDeletion ? '' : await _decryptRow(row),
          recordedAt: DateTime.parse(row['recorded_at'] as String),
          recordedById: row['recorded_by_id'] as String?,
          isDeletion: isDeletion,
        );
      }),
    );
  }

  static Future<Map<String, Object?>> _currentRevision(
    DatabaseExecutor db,
    String messageId,
  ) async {
    final rows = await db.query(
      'message_revisions',
      where: 'logical_id = ?',
      whereArgs: [messageId],
      orderBy: 'revision DESC',
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Message not found: $messageId');
    return rows.single;
  }

  static Future<int> _markSeen(
    DatabaseExecutor db,
    String messageId,
    String memberId,
    DateTime seenAt,
  ) => db.insert('message_receipts', {
    'logical_id': messageId,
    'member_id': memberId,
    'seen_at': seenAt.toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  static Future<void> _requireConversationMember(
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

  Future<Message> _messageFromRow(Map<String, Object?> row) async {
    final seen =
        (row['seen_by'] as String?)
            ?.split(',')
            .where((id) => id.isNotEmpty)
            .toSet() ??
        <String>{};
    final revision = row['revision'] as int;
    return Message(
      id: row['logical_id'] as String,
      revisionId: row['revision_id'] as int,
      author: row['author_id'] == null
          ? null
          : SystemMember.fromStorage(
              id: row['author_id'] as String,
              name: row['author_name'] as String,
            ),
      text: await _decryptRow(row),
      createdAt: DateTime.parse(row['created_at'] as String),
      editedAt: revision > 1
          ? DateTime.parse(row['recorded_at'] as String)
          : null,
      revision: revision,
      isPinned: row['pinned'] != null,
      seenBy: seen,
      seenByNames:
          (row['seen_by_names'] as String?)
              ?.split(String.fromCharCode(31))
              .where((name) => name.isNotEmpty)
              .toList(growable: false) ??
          const [],
      visibility: MessageVisibility.values.byName(row['visibility'] as String),
      recipientIds:
          (row['recipient_ids'] as String?)
              ?.split(',')
              .where((id) => id.isNotEmpty)
              .toSet() ??
          const {},
      recipientNames:
          (row['recipient_names'] as String?)
              ?.split(String.fromCharCode(31))
              .where((name) => name.isNotEmpty)
              .toList(growable: false) ??
          const [],
      sourceMessageId: row['source_message_id'] as String?,
      sourceConversationTitle: row['source_conversation_title'] as String?,
    );
  }

  Future<void> _ensureEncryption() async {
    final pending = _encryptionReady ??= _encryptLegacyRows();
    try {
      await pending;
    } catch (_) {
      _encryptionReady = null;
      rethrow;
    }
  }

  Future<void> _encryptLegacyRows() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'message_revisions',
      where: 'encryption_version = 0 AND deleted_at IS NULL AND content <> ?',
      whereArgs: [''],
    );
    for (final row in rows) {
      final messageId = row['logical_id'] as String;
      final revision = row['revision'] as int;
      final encrypted = await _cipher.encrypt(
        row['content'] as String,
        messageId: messageId,
        revision: revision,
      );
      await db.update(
        'message_revisions',
        _encryptedColumns(encrypted),
        where: 'revision_id = ? AND encryption_version = 0',
        whereArgs: [row['revision_id']],
      );
    }
    if (rows.isNotEmpty) {
      // Updating a row does not remove its old bytes from SQLite free pages or
      // the WAL. Rewrite the database after the one-time plaintext migration.
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      await db.execute('VACUUM');
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    }
  }

  Future<String> _decryptRow(Map<String, Object?> row) {
    final version = row['encryption_version'] as int;
    if (version == 0) return Future.value(row['content'] as String);
    final cipherText = row['content_ciphertext'] as String?;
    final nonce = row['content_nonce'] as String?;
    final mac = row['content_mac'] as String?;
    if (cipherText == null || nonce == null || mac == null) {
      throw StateError('Encrypted message content is incomplete');
    }
    return _cipher.decrypt(
      EncryptedMessageContent(
        cipherText: cipherText,
        nonce: nonce,
        mac: mac,
        version: version,
      ),
      messageId: row['logical_id'] as String,
      revision: row['revision'] as int,
    );
  }

  static Map<String, Object?> _encryptedColumns(
    EncryptedMessageContent encrypted,
  ) => {
    'content': '',
    'content_ciphertext': encrypted.cipherText,
    'content_nonce': encrypted.nonce,
    'content_mac': encrypted.mac,
    'encryption_version': encrypted.version,
  };
}

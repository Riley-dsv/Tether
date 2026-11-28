import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/handovers/handover.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_cipher.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late WorkspaceRepository workspace;
  late MemberRepository members;
  late MessageRepository repository;
  late HandoverRepository handoverRepository;
  late SystemLogRepository systemLogRepository;
  late String conversationId;
  late String memberOneId;
  late String memberTwoId;
  late String memberThreeId;

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await database.database;
    workspace = WorkspaceRepository(database);
    members = MemberRepository(database, pinCodec: _testPinCodec());
    repository = MessageRepository(
      database,
      cipher: AesGcmMessageCipher.fromKeyBytes(List<int>.filled(32, 7)),
    );
    handoverRepository = HandoverRepository(database);
    systemLogRepository = SystemLogRepository(database);
    expect(await members.members(), isEmpty);
    final initialConversations = await workspace.conversations();
    expect(initialConversations, hasLength(1));
    expect(initialConversations.single.isGeneral, isTrue);
    memberOneId = (await members.createMember('Member One', pin: '1234')).id;
    memberTwoId = (await members.createMember('Member Two', pin: '1234')).id;
    memberThreeId = (await members.createMember(
      'Member Three',
      pin: '1234',
    )).id;
    conversationId = (await workspace.createConversation(
      title: 'Test conversation',
      memberIds: {memberOneId, memberTwoId, memberThreeId},
    )).id;
  });

  tearDown(() => database.close());

  test('version 3 databases migrate visibility without losing entities', () async {
    final path =
        '/tmp/tether_migration_${DateTime.now().microsecondsSinceEpoch}.db';
    addTearDown(() => databaseFactoryFfi.deleteDatabase(path));
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE members (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE conversation_members (conversation_id TEXT NOT NULL, member_id TEXT NOT NULL, joined_at TEXT NOT NULL, PRIMARY KEY (conversation_id, member_id))',
          );
          await db.execute(
            'CREATE TABLE message_entities (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL REFERENCES conversations(id), created_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE message_revisions (revision_id INTEGER PRIMARY KEY AUTOINCREMENT, logical_id TEXT NOT NULL, conversation_id TEXT NOT NULL, author_id TEXT, recorded_by_id TEXT, content TEXT NOT NULL, revision INTEGER NOT NULL, created_at TEXT NOT NULL, recorded_at TEXT NOT NULL, supersedes_revision_id INTEGER, deleted_at TEXT, UNIQUE(logical_id, revision))',
          );
          await db.execute(
            'CREATE TABLE message_pins (logical_id TEXT PRIMARY KEY, pinned_by TEXT, pinned_at TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE message_receipts (logical_id TEXT NOT NULL, member_id TEXT NOT NULL, seen_at TEXT NOT NULL, PRIMARY KEY (logical_id, member_id))',
          );
          await db.insert('conversations', {
            'id': 'space',
            'title': 'Existing space',
            'created_at': '2026-01-01T00:00:00Z',
          });
          await db.insert('members', {
            'id': 'legacy_member',
            'display_name': 'Legacy member',
            'created_at': '2026-01-01T00:00:00Z',
          });
          await db.insert('message_entities', {
            'id': 'message',
            'conversation_id': 'space',
            'created_at': '2026-01-01T00:00:00Z',
          });
        },
      ),
    );
    await old.close();

    final migrated = AppDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(migrated.close);
    final db = await migrated.database;
    final entity = (await db.query('message_entities')).single;
    expect(entity['id'], 'message');
    expect(entity['visibility'], 'shared');
    expect(await db.query('message_recipients'), isEmpty);
    final legacyMembers = await MemberRepository(migrated).members();
    expect(legacyMembers.single.id, 'legacy_member');
    expect(legacyMembers.single.hasPin, isFalse);
  });

  test('members and conversations are created from user input', () async {
    final activeMembers = await members.members();
    final conversations = await workspace.conversations();
    expect(
      activeMembers.map((member) => member.name),
      containsAll(['Member One', 'Member Two']),
    );
    final group = conversations.singleWhere(
      (conversation) => !conversation.isGeneral,
    );
    expect(group.title, 'Test conversation');
    expect(group.members, hasLength(3));
    final general = conversations.singleWhere(
      (conversation) => conversation.isGeneral,
    );
    expect(general.title, 'General');
    expect(
      general.members.map((member) => member.id),
      containsAll([memberOneId, memberTwoId, memberThreeId]),
    );
  });

  test('members can be renamed and archived without losing history', () async {
    final message = await repository.create(
      conversationId: conversationId,
      content: 'Keep my attribution',
      authorId: memberThreeId,
    );
    final renamed = await members.renameMember(
      memberId: memberThreeId,
      displayName: 'Renamed Member',
    );
    expect(renamed.name, 'Renamed Member');
    expect(
      (await members.members()).map((member) => member.name),
      contains('Renamed Member'),
    );

    await members.archiveMember(memberThreeId);

    expect(
      (await members.members()).map((member) => member.id),
      isNot(contains(memberThreeId)),
    );
    expect(
      (await workspace.conversations())
          .singleWhere((conversation) => conversation.id == conversationId)
          .members
          .map((member) => member.id),
      isNot(contains(memberThreeId)),
    );
    final historical = await repository.watchSnapshot(
      conversationId: conversationId,
      viewerId: memberOneId,
    );
    expect(
      historical.singleWhere((item) => item.id == message.id).author?.name,
      'Renamed Member',
    );
  });

  test(
    'handovers persist recipients, priority, tasks, expiry, and receipts',
    () async {
      final expiry = DateTime.now().add(const Duration(days: 2));
      await handoverRepository.create(
        conversationId: conversationId,
        summary: 'Call the dentist tomorrow',
        recipientIds: {memberTwoId},
        priority: HandoverPriority.urgent,
        authorId: memberOneId,
        context: 'The office opens at nine.',
        expiresAt: expiry,
        items: const [
          HandoverItem(description: 'Groceries done', isCompleted: true),
          HandoverItem(description: 'Call the dentist', isCompleted: false),
        ],
      );

      final recipientView = await handoverRepository.list(
        conversationId: conversationId,
        viewerId: memberTwoId,
      );
      expect(recipientView.single.priority, HandoverPriority.urgent);
      expect(recipientView.single.recipients.single.id, memberTwoId);
      expect(recipientView.single.items, hasLength(2));
      expect(recipientView.single.items.first.isCompleted, isTrue);
      expect(recipientView.single.expiresAt, isNotNull);
      expect(
        await handoverRepository.list(
          conversationId: conversationId,
          viewerId: memberThreeId,
        ),
        isEmpty,
      );

      await handoverRepository.markRead(
        handoverId: recipientView.single.id,
        memberId: memberTwoId,
      );
      final read = await handoverRepository.list(
        conversationId: conversationId,
        viewerId: memberTwoId,
      );
      expect(read.single.readBy, containsAll([memberOneId, memberTwoId]));
      final recipientLog = await systemLogRepository.list(
        viewerId: memberTwoId,
      );
      expect(
        recipientLog.map((event) => event.type),
        containsAll([
          'handover_created',
          'task_created',
          'task_completed',
          'handover_read',
        ]),
      );
      final outsideLog = await systemLogRepository.list(
        viewerId: memberThreeId,
      );
      expect(
        outsideLog.map((event) => event.type),
        isNot(contains('handover_created')),
      );
    },
  );

  test('technical system events are hidden unless requested', () async {
    final db = await database.database;
    await SystemLogRepository.record(
      db,
      type: 'maintenance',
      summary: 'performed maintenance',
      isTechnical: true,
    );
    expect(
      (await systemLogRepository.list(
        viewerId: memberOneId,
      )).map((event) => event.type),
      isNot(contains('maintenance')),
    );
    expect(
      (await systemLogRepository.list(
        viewerId: memberOneId,
        includeTechnical: true,
      )).map((event) => event.type),
      contains('maintenance'),
    );
  });

  test('targeted messages are projected only to their audience', () async {
    final privateMessage = await repository.create(
      conversationId: conversationId,
      content: 'For one member',
      authorId: memberOneId,
      recipientIds: {memberTwoId},
    );
    expect(privateMessage.visibility, MessageVisibility.private);
    expect(
      await repository.watchSnapshot(
        conversationId: conversationId,
        viewerId: memberTwoId,
      ),
      hasLength(1),
    );
    expect(
      await repository.watchSnapshot(
        conversationId: conversationId,
        viewerId: memberThreeId,
      ),
      isEmpty,
    );
    expect(
      await repository.unreadCount(
        conversationId: conversationId,
        memberId: memberThreeId,
      ),
      0,
    );

    final groupMessage = await repository.create(
      conversationId: conversationId,
      content: 'For a selected group',
      authorId: memberOneId,
      recipientIds: {memberTwoId, memberThreeId},
    );
    expect(groupMessage.visibility, MessageVisibility.group);
    expect(
      groupMessage.recipientNames,
      containsAll(['Member Two', 'Member Three']),
    );
  });

  test('message bodies are authenticated and encrypted at rest', () async {
    final created = await repository.create(
      conversationId: conversationId,
      content: 'Sensitive internal context',
      authorId: memberOneId,
    );

    final db = await database.database;
    final stored = (await db.query(
      'message_revisions',
      where: 'logical_id = ?',
      whereArgs: [created.id],
    )).single;
    expect(stored['content'], '');
    expect(stored['encryption_version'], 1);
    expect(stored['content_ciphertext'], isNotNull);
    expect(stored['content_ciphertext'], isNot(contains('Sensitive')));
    expect(stored['content_nonce'], isNotNull);
    expect(stored['content_mac'], isNotNull);

    final visible = await repository.watchSnapshot(
      conversationId: conversationId,
      viewerId: memberOneId,
    );
    expect(visible.single.text, 'Sensitive internal context');
  });

  test(
    'legacy plaintext revisions are encrypted before being returned',
    () async {
      final db = await database.database;
      const messageId = 'legacy-message';
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('message_entities', {
        'id': messageId,
        'conversation_id': conversationId,
        'created_at': now,
        'visibility': 'shared',
      });
      await db.insert('message_revisions', {
        'logical_id': messageId,
        'conversation_id': conversationId,
        'author_id': memberOneId,
        'recorded_by_id': memberOneId,
        'content': 'Old plaintext message',
        'revision': 1,
        'created_at': now,
        'recorded_at': now,
      });

      final migrationRepository = MessageRepository(
        database,
        cipher: AesGcmMessageCipher.fromKeyBytes(List<int>.filled(32, 7)),
      );
      final messages = await migrationRepository.watchSnapshot(
        conversationId: conversationId,
        viewerId: memberOneId,
      );
      expect(messages.single.text, 'Old plaintext message');

      final stored = (await db.query(
        'message_revisions',
        where: 'logical_id = ?',
        whereArgs: [messageId],
      )).single;
      expect(stored['content'], '');
      expect(stored['encryption_version'], 1);
    },
  );

  test('transfers retain a traceable source link', () async {
    final target = await workspace.createConversation(
      title: 'Target space',
      memberIds: {memberOneId},
    );
    final source = await repository.create(
      conversationId: conversationId,
      content: 'Transfer this information',
      authorId: memberOneId,
    );
    await repository.create(
      conversationId: target.id,
      content: source.text,
      authorId: memberOneId,
      sourceMessageId: source.id,
    );
    final transferred = await repository.watchSnapshot(
      conversationId: target.id,
      viewerId: memberOneId,
    );
    expect(transferred.single.sourceMessageId, source.id);
    expect(transferred.single.sourceConversationTitle, 'Test conversation');
  });

  test('edit and deletion append revisions without losing history', () async {
    final created = await repository.create(
      conversationId: conversationId,
      content: 'Original appointment note',
      authorId: memberOneId,
    );
    await repository.edit(
      messageId: created.id,
      content: 'Corrected appointment note',
      editedById: memberTwoId,
    );

    final current = await repository.watchSnapshot(
      conversationId: conversationId,
    );
    expect(current.single.text, 'Corrected appointment note');
    expect(current.single.revision, 2);
    expect(
      await repository.watchSnapshot(
        conversationId: conversationId,
        query: 'Original',
      ),
      isEmpty,
    );
    expect(
      await repository.watchSnapshot(
        conversationId: conversationId,
        query: 'Corrected',
      ),
      hasLength(1),
    );

    await repository.delete(messageId: created.id, deletedById: memberTwoId);
    expect(
      await repository.watchSnapshot(conversationId: conversationId),
      isEmpty,
    );
    final history = await repository.history(created.id, viewerId: memberOneId);
    expect(history, hasLength(3));
    expect(history.first.isDeletion, isTrue);
    expect(history.last.content, 'Original appointment note');
  });

  test('pins survive edits and filter the conversation', () async {
    final message = await repository.create(
      conversationId: conversationId,
      content: 'Keep this visible',
      authorId: memberOneId,
    );
    await repository.setPinned(
      messageId: message.id,
      pinned: true,
      actorId: memberTwoId,
    );
    await repository.edit(
      messageId: message.id,
      content: 'Keep this updated',
      editedById: memberTwoId,
    );
    final pinned = await repository.watchSnapshot(
      conversationId: conversationId,
      pinnedOnly: true,
    );
    expect(pinned.single.isPinned, isTrue);
    expect(pinned.single.text, 'Keep this updated');
  });

  test('seen receipts produce a per-member unread count', () async {
    final message = await repository.create(
      conversationId: conversationId,
      content: 'Please read this',
      authorId: memberOneId,
    );
    expect(message.seenBy, contains(memberOneId));
    expect(
      await repository.unreadCount(
        conversationId: conversationId,
        memberId: memberTwoId,
      ),
      1,
    );
    await repository.markSeen(messageId: message.id, memberId: memberTwoId);
    expect(
      await repository.unreadCount(
        conversationId: conversationId,
        memberId: memberTwoId,
      ),
      0,
    );
    final refreshed = await repository.watchSnapshot(
      conversationId: conversationId,
    );
    expect(
      refreshed.single.seenByNames,
      containsAll(['Member One', 'Member Two']),
    );
    final conversations = await workspace.conversations(viewerId: memberTwoId);
    expect(
      conversations
          .singleWhere((conversation) => conversation.id == conversationId)
          .unreadCount,
      0,
    );
  });

  test('message relationships and membership are enforced', () async {
    final outsider = await members.createMember('Outside Member', pin: '1234');
    await expectLater(
      repository.create(
        conversationId: conversationId,
        content: 'Not allowed',
        authorId: outsider.id,
      ),
      throwsStateError,
    );

    final message = await repository.create(
      conversationId: conversationId,
      content: 'Valid message',
      authorId: memberOneId,
    );
    await expectLater(
      repository.markSeen(messageId: message.id, memberId: outsider.id),
      throwsStateError,
    );
    final db = await database.database;
    final entities = await db.query(
      'message_entities',
      where: 'id = ?',
      whereArgs: [message.id],
    );
    expect(entities, hasLength(1));
  });

  test('search treats wildcard characters literally', () async {
    await repository.create(
      conversationId: conversationId,
      content: 'A normal message',
    );
    expect(
      await repository.watchSnapshot(
        conversationId: conversationId,
        query: '%',
      ),
      isEmpty,
    );
  });

  test('message history paginates without gaps or duplicates', () async {
    for (var index = 0; index < 65; index++) {
      await repository.create(
        conversationId: conversationId,
        content: 'Paged message $index',
        authorId: memberOneId,
      );
    }

    final first = await repository.watchSnapshot(
      conversationId: conversationId,
      viewerId: memberOneId,
      limit: 31,
    );
    expect(first, hasLength(31));
    final firstPage = first.take(30).toList();
    final firstCursor = firstPage.last;
    final second = await repository.watchSnapshot(
      conversationId: conversationId,
      viewerId: memberOneId,
      before: MessageCursor(
        createdAt: firstCursor.createdAt,
        revisionId: firstCursor.revisionId,
      ),
      limit: 31,
    );
    final secondPage = second.take(30).toList();
    final secondCursor = secondPage.last;
    final third = await repository.watchSnapshot(
      conversationId: conversationId,
      viewerId: memberOneId,
      before: MessageCursor(
        createdAt: secondCursor.createdAt,
        revisionId: secondCursor.revisionId,
      ),
      limit: 31,
    );

    final allIds = [
      ...firstPage.map((message) => message.id),
      ...secondPage.map((message) => message.id),
      ...third.map((message) => message.id),
    ];
    expect(allIds, hasLength(65));
    expect(allIds.toSet(), hasLength(65));
    expect(firstPage.first.text, 'Paged message 64');
    expect(third.last.text, 'Paged message 0');
  });
}

MemberPinCodec _testPinCodec() => MemberPinCodec(
  iterations: 10,
  runInBackground: false,
  createSalt: () => List<int>.filled(16, 7),
);

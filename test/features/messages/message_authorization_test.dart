import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_cipher.dart';
import 'package:note_app/features/messages/message_notification_policy.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late MemberRepository members;
  late WorkspaceRepository workspace;
  late MessageRepository messages;
  late SystemLogRepository systemLog;
  late String aliceId;
  late String morganId;
  late String irisId;
  late String conversationId;

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    members = MemberRepository(
      database,
      pinCodec: MemberPinCodec(
        iterations: 10,
        memory: 32,
        parallelism: 1,
        runInBackground: false,
        createSalt: () => List<int>.filled(16, 4),
      ),
    );
    workspace = WorkspaceRepository(database);
    messages = MessageRepository(
      database,
      cipher: AesGcmMessageCipher.fromKeyBytes(List<int>.filled(32, 9)),
    );
    systemLog = SystemLogRepository(database);
    aliceId = (await members.createMember('Alice', pin: '1234')).id;
    morganId = (await members.createMember('Morgan', pin: '1234')).id;
    irisId = (await members.createMember('Iris', pin: '1234')).id;
    conversationId = (await workspace.createConversation(
      title: 'Everyone',
      memberIds: {aliceId, morganId, irisId},
    )).id;
  });

  tearDown(() => database.close());

  Future<Message> privateMessage() => messages.create(
    conversationId: conversationId,
    content: 'dentist access code 2468',
    authorId: aliceId,
    recipientIds: {morganId},
  );

  test('global search returns only authorized message content', () async {
    await privateMessage();

    expect(
      await messages.watchSnapshot(
        conversationId: conversationId,
        query: 'access code',
        viewerId: irisId,
      ),
      isEmpty,
    );
    expect(
      await messages.watchSnapshot(
        conversationId: conversationId,
        query: 'access code',
        viewerId: morganId,
      ),
      hasLength(1),
    );
    expect(
      await messages.watchSnapshot(
        conversationId: conversationId,
        query: 'access code',
      ),
      isEmpty,
    );
  });

  test('revisions and tombstones require message visibility', () async {
    final message = await privateMessage();
    await messages.edit(
      messageId: message.id,
      content: 'updated private code',
      editedById: morganId,
    );
    await messages.delete(messageId: message.id, deletedById: aliceId);

    await expectLater(
      messages.history(message.id, viewerId: irisId),
      throwsStateError,
    );
    await expectLater(messages.history(message.id), throwsStateError);
    final authorized = await messages.history(message.id, viewerId: morganId);
    expect(authorized.first.isDeletion, isTrue);
    expect(authorized, hasLength(3));
  });

  test('system log hides events for private content', () async {
    await privateMessage();

    final outsider = await systemLog.list(viewerId: irisId);
    final recipient = await systemLog.list(viewerId: morganId);

    expect(outsider.where((event) => event.type == 'message_created'), isEmpty);
    expect(
      recipient.where((event) => event.type == 'message_created'),
      hasLength(1),
    );
    final anonymous = await systemLog.list();
    expect(
      anonymous.where((event) => event.conversationTitle == 'Everyone'),
      isEmpty,
    );
  });

  test('message transfer cannot bypass source authorization', () async {
    final source = await privateMessage();
    final general = (await workspace.conversations()).singleWhere(
      (conversation) => conversation.isGeneral,
    );

    await expectLater(
      messages.create(
        conversationId: general.id,
        content: source.text,
        authorId: irisId,
        sourceMessageId: source.id,
      ),
      throwsStateError,
    );
    expect(
      await messages.watchSnapshot(
        conversationId: general.id,
        query: 'dentist access',
        viewerId: irisId,
      ),
      isEmpty,
    );
  });

  test('notification previews never leak protected content', () async {
    final message = await privateMessage();

    expect(
      MessageNotificationPolicy.preview(message, viewerId: irisId),
      'New protected message',
    );
    expect(
      MessageNotificationPolicy.preview(message, viewerId: morganId),
      message.text,
    );
    expect(MessageNotificationPolicy.preview(message), 'New protected message');
  });
}

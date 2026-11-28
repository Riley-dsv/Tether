import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/handovers/handover.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/home/home_summary.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/messages/message_cipher.dart';
import 'package:note_app/features/tasks/task.dart';
import 'package:note_app/features/tasks/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('home summary aggregates the current member actionable items', () async {
    final database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(database.close);
    final workspace = WorkspaceRepository(database);
    final members = MemberRepository(database, pinCodec: _testPinCodec());
    final alice = await members.createMember('Alice', pin: '1234');
    final morgan = await members.createMember('Morgan', pin: '1234');
    final conversation = await workspace.createConversation(
      title: 'Home',
      memberIds: {alice.id, morgan.id},
    );
    await MessageRepository(
      database,
      cipher: AesGcmMessageCipher.fromKeyBytes(List<int>.filled(32, 7)),
    ).create(
      conversationId: conversation.id,
      content: 'Please check this',
      authorId: alice.id,
      recipientIds: {morgan.id},
    );
    await HandoverRepository(database).create(
      conversationId: conversation.id,
      summary: 'Important context',
      recipientIds: {morgan.id},
      priority: HandoverPriority.high,
      items: const [],
      authorId: alice.id,
    );
    final now = DateTime.now();
    final reminder = now.add(const Duration(hours: 1));
    final deadline = now.add(const Duration(hours: 2));
    await TaskRepository(database).create(
      conversationId: conversation.id,
      title: 'Due today',
      assignment: TaskAssignment.specific,
      assigneeIds: {morgan.id},
      status: TaskStatus.todo,
      authorId: alice.id,
      reminderAt: reminder,
      deadline: deadline,
    );

    final summary = await HomeRepository(database).summary(viewerId: morgan.id);

    expect(summary.unreadMessages, 1);
    expect(summary.importantHandovers, 1);
    expect(summary.tasksToday, 1);
    expect(summary.nextItem?.kind, HomeNextItemKind.reminder);
    expect(summary.nextItem?.title, 'Due today');
  });
}

MemberPinCodec _testPinCodec() => MemberPinCodec(
  iterations: 10,
  memory: 32,
  parallelism: 1,
  runInBackground: false,
  createSalt: () => List<int>.filled(16, 7),
);

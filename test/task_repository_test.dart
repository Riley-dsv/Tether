import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/features/tasks/task.dart';
import 'package:note_app/features/tasks/task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late WorkspaceRepository workspace;
  late MemberRepository members;
  late TaskRepository tasks;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    workspace = WorkspaceRepository(database);
    members = MemberRepository(database, pinCodec: _testPinCodec());
    tasks = TaskRepository(database);
  });

  tearDown(() => database.close());

  test('persists anyone and multiple-assignee task modes', () async {
    final alice = await members.createMember('Alice', pin: '1234');
    final morgan = await members.createMember('Morgan', pin: '1234');
    final conversation = await workspace.createConversation(
      title: 'Shared space',
      memberIds: {alice.id, morgan.id},
    );

    await tasks.create(
      conversationId: conversation.id,
      title: 'Take out recycling',
      assignment: TaskAssignment.anyone,
      assigneeIds: const {},
      status: TaskStatus.todo,
      authorId: alice.id,
    );
    await tasks.create(
      conversationId: conversation.id,
      title: 'File the tax return',
      assignment: TaskAssignment.specific,
      assigneeIds: {alice.id, morgan.id},
      status: TaskStatus.todo,
      deadline: DateTime.utc(2027, 1, 15),
      reminderAt: DateTime.utc(2027, 1, 15, 9),
      authorId: morgan.id,
    );

    final stored = await tasks.list(
      conversationId: conversation.id,
      viewerId: alice.id,
    );
    final anyone = stored.singleWhere(
      (task) => task.title == 'Take out recycling',
    );
    final assigned = stored.singleWhere(
      (task) => task.title == 'File the tax return',
    );

    expect(anyone.assignment, TaskAssignment.anyone);
    expect(anyone.assignees, isEmpty);
    expect(assigned.assignment, TaskAssignment.specific);
    expect(
      assigned.assignees.map((member) => member.name),
      containsAll(['Alice', 'Morgan']),
    );
    expect(assigned.deadline, DateTime.utc(2027, 1, 15));
    expect(assigned.reminderAt, DateTime.utc(2027, 1, 15, 9));

    await tasks.updateStatus(
      taskId: assigned.id,
      status: TaskStatus.done,
      actorId: alice.id,
    );
    final updated = await tasks.list(
      conversationId: conversation.id,
      viewerId: morgan.id,
    );
    expect(
      updated.singleWhere((task) => task.id == assigned.id).status,
      TaskStatus.done,
    );

    final events = await SystemLogRepository(database).list(viewerId: alice.id);
    final assignedEvents = events.where(
      (event) => event.relatedTaskId == assigned.id,
    );
    expect(
      assignedEvents.map((event) => event.type),
      containsAll(['task_created', 'task_completed']),
    );

    final db = await database.database;
    final indexes = await db.rawQuery("PRAGMA index_list('system_events')");
    expect(
      indexes.map((index) => index['name']),
      contains('idx_system_events_task'),
    );
  });

  test('specific assignment requires at least one assignee', () async {
    final alice = await members.createMember('Alice', pin: '1234');
    final conversation = await workspace.createConversation(
      title: 'Home',
      memberIds: {alice.id},
    );

    await expectLater(
      tasks.create(
        conversationId: conversation.id,
        title: 'Rigid but empty',
        assignment: TaskAssignment.specific,
        assigneeIds: const {},
        status: TaskStatus.todo,
      ),
      throwsArgumentError,
    );
  });
}

MemberPinCodec _testPinCodec() => MemberPinCodec(
  iterations: 10,
  memory: 32,
  parallelism: 1,
  runInBackground: false,
  createSalt: () => List<int>.filled(16, 7),
);

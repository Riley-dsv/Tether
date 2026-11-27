import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/app/app_dependencies.dart';
import 'package:note_app/app/tether_app.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/conversation.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/handovers/handover.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_cipher.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/system_log/system_event.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/features/tasks/task.dart';
import 'package:note_app/features/tasks/task_repository.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('workspace starts with an anonymous dashboard and no fixtures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TetherApp(
        dependencies: AppDependencies(
          database: AppDatabase(
            factory: databaseFactoryFfi,
            path: inMemoryDatabasePath,
          ),
          messages: _EmptyRepository(),
          members: _EmptyMemberStore(),
          workspace: _EmptyWorkspaceRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('A shared overview without assigning an identity.'),
      findsOneWidget,
    );
    expect(find.text('Open shared conversation'), findsOneWidget);
    expect(find.text('New conversation'), findsOneWidget);
    expect(find.text('Create member'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('workspace fits a narrow phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TetherApp(
        dependencies: AppDependencies(
          database: AppDatabase(
            factory: databaseFactoryFfi,
            path: inMemoryDatabasePath,
          ),
          messages: _EmptyRepository(),
          members: _EmptyMemberStore(),
          workspace: _EmptyWorkspaceRepository(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Home'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile bottom navigation opens feature views', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TetherApp(
        dependencies: AppDependencies(
          database: AppDatabase(
            factory: databaseFactoryFfi,
            path: inMemoryDatabasePath,
          ),
          messages: _EmptyRepository(),
          members: _PopulatedMemberStore(),
          workspace: _PopulatedWorkspaceRepository(),
          tasks: _EmptyTaskStore(),
          handovers: _EmptyHandoverStore(),
          systemLog: _EmptySystemLogStore(),
        ),
      ),
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Unknown is an anonymous viewing state, not a missing member selection.
    expect(
      find.text('A shared overview without assigning an identity.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Messages'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('message-author-selector')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('message-author-morgan')));
    await tester.tap(find.byKey(const Key('message-author-morgan')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('message-current-author'))).data,
      'Morgan',
    );
    await tester.tap(find.byKey(const Key('message-author-selector')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('message-author-unknown')));
    await tester.tap(find.byKey(const Key('message-author-unknown')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('message-current-author'))).data,
      'Unknown',
    );

    await tester.tap(find.text('Tasks'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tasks & reminders'), findsOneWidget);

    await tester.tap(find.text('Handovers'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Handovers'), findsWidgets);

    await tester.tap(find.text('Log'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('System log'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _EmptyWorkspaceRepository extends WorkspaceRepository {
  _EmptyWorkspaceRepository()
    : super(
        AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
      );

  @override
  Future<List<Conversation>> conversations({String? viewerId}) async =>
      const [];
}

class _PopulatedWorkspaceRepository extends _EmptyWorkspaceRepository {
  final member = _testMember;

  @override
  Future<List<Conversation>> conversations({String? viewerId}) async => [
    Conversation(
      id: 'shared-space',
      title: 'Shared space',
      createdAt: DateTime.utc(2026),
      members: [member],
      unreadCount: 0,
    ),
  ];
}

final _testMember = SystemMember.fromStorage(id: 'morgan', name: 'Morgan');

class _EmptyMemberStore implements MemberStore {
  @override
  Future<List<SystemMember>> members() async => const [];

  @override
  Future<SystemMember> createMember(String displayName) =>
      throw UnimplementedError();

  @override
  Future<SystemMember> renameMember({
    required String memberId,
    required String displayName,
  }) => throw UnimplementedError();

  @override
  Future<void> archiveMember(String memberId) => throw UnimplementedError();
}

class _PopulatedMemberStore extends _EmptyMemberStore {
  @override
  Future<List<SystemMember>> members() async => [_testMember];
}

class _EmptyRepository extends MessageRepository {
  _EmptyRepository()
    : super(
        AppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath),
        cipher: AesGcmMessageCipher.fromKeyBytes(List<int>.filled(32, 7)),
      );

  @override
  Future<void> prepare() async {}

  @override
  Future<List<Message>> watchSnapshot({
    required String conversationId,
    String query = '',
    bool pinnedOnly = false,
    String? viewerId,
    MessageCursor? before,
    int? limit,
  }) async => const [];

  @override
  Future<int> unreadCount({
    required String conversationId,
    required String memberId,
  }) async => 0;
}

class _EmptyTaskStore implements TaskStore {
  @override
  Future<List<WorkspaceTask>> list({
    required String conversationId,
    String? viewerId,
  }) async => const [];

  @override
  Future<void> create({
    required String conversationId,
    required String title,
    required TaskAssignment assignment,
    required Set<String> assigneeIds,
    required TaskStatus status,
    String? authorId,
    DateTime? deadline,
    DateTime? reminderAt,
  }) async {}

  @override
  Future<void> updateStatus({
    required String taskId,
    required TaskStatus status,
    String? actorId,
  }) async {}
}

class _EmptyHandoverStore implements HandoverStore {
  @override
  Future<List<Handover>> list({
    required String conversationId,
    String? viewerId,
  }) async => const [];

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
  }) async {}

  @override
  Future<void> markRead({
    required String handoverId,
    required String memberId,
  }) async {}
}

class _EmptySystemLogStore implements SystemLogStore {
  @override
  Future<List<SystemEvent>> list({
    String? viewerId,
    bool includeTechnical = false,
    int limit = 250,
  }) async => const [];
}

import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/features/tasks/task_repository.dart';

/// Application composition root. Concrete persistence is wired here, while
/// features depend only on the narrow store contracts they use.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.messages,
    required this.workspace,
    required this.handovers,
    required this.home,
    required this.systemLog,
    required this.tasks,
    required bool ownsDatabase,
  }) : _ownsDatabase = ownsDatabase;

  factory AppDependencies({
    AppDatabase? database,
    MessageStore? messages,
    WorkspaceStore? workspace,
    HandoverStore? handovers,
    HomeStore? home,
    SystemLogStore? systemLog,
    TaskStore? tasks,
  }) {
    final resolvedDatabase = database ?? AppDatabase();
    return AppDependencies._(
      database: resolvedDatabase,
      messages: messages ?? MessageRepository(resolvedDatabase),
      workspace: workspace ?? WorkspaceRepository(resolvedDatabase),
      handovers: handovers ?? HandoverRepository(resolvedDatabase),
      home: home ?? HomeRepository(resolvedDatabase),
      systemLog: systemLog ?? SystemLogRepository(resolvedDatabase),
      tasks: tasks ?? TaskRepository(resolvedDatabase),
      ownsDatabase: database == null,
    );
  }

  final AppDatabase database;
  final MessageStore messages;
  final WorkspaceStore workspace;
  final HandoverStore handovers;
  final HomeStore home;
  final SystemLogStore systemLog;
  final TaskStore tasks;
  final bool _ownsDatabase;

  Future<void> dispose() async {
    if (_ownsDatabase) await database.close();
  }
}

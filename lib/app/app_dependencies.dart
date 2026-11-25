import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/messages/message_cipher.dart';
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

  /// Creates the production dependency graph with optional test overrides.
  ///
  /// When [database] is supplied, ownership remains with the caller and
  /// [dispose] will not close it. The default message store uses a key held in
  /// platform secure storage.
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
      messages:
          messages ??
          MessageRepository(
            resolvedDatabase,
            cipher: AesGcmMessageCipher(SecureStorageMessageKeyProvider()),
          ),
      workspace: workspace ?? WorkspaceRepository(resolvedDatabase),
      handovers: handovers ?? HandoverRepository(resolvedDatabase),
      home: home ?? HomeRepository(resolvedDatabase),
      systemLog: systemLog ?? SystemLogRepository(resolvedDatabase),
      tasks: tasks ?? TaskRepository(resolvedDatabase),
      ownsDatabase: database == null,
    );
  }

  /// Shared database connection owner.
  final AppDatabase database;

  /// Message persistence and revision operations.
  final MessageStore messages;

  /// Member and conversation persistence.
  final WorkspaceStore workspace;

  /// Structured handover persistence.
  final HandoverStore handovers;

  /// Dashboard aggregation.
  final HomeStore home;

  /// Cross-cutting audit feed persistence.
  final SystemLogStore systemLog;

  /// Task and reminder persistence.
  final TaskStore tasks;
  final bool _ownsDatabase;

  /// Releases resources owned by this composition root.
  ///
  /// Injected databases are intentionally not closed.
  Future<void> dispose() async {
    if (_ownsDatabase) await database.close();
  }
}

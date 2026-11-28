import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/messages/message_cipher.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/members/member_authenticator.dart';
import 'package:note_app/features/members/member_session.dart';
import 'package:note_app/features/members/session_bound_stores.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/features/tasks/task_repository.dart';

/// Application composition root. Concrete persistence is wired here, while
/// features depend only on the narrow store contracts they use.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.messages,
    required this.members,
    required this.authentication,
    required this.session,
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
    MemberStore? members,
    MemberAuthentication? authentication,
    MemberSession? session,
    WorkspaceStore? workspace,
    HandoverStore? handovers,
    HomeStore? home,
    SystemLogStore? systemLog,
    TaskStore? tasks,
  }) {
    final resolvedDatabase = database ?? AppDatabase();
    final resolvedMembers = members ?? MemberRepository(resolvedDatabase);
    final resolvedSession = session ?? MemberSession();
    final resolvedMessages =
        messages ??
        MessageRepository(
          resolvedDatabase,
          cipher: AesGcmMessageCipher(SecureStorageMessageKeyProvider()),
        );
    final resolvedHome = home ?? HomeRepository(resolvedDatabase);
    final resolvedSystemLog =
        systemLog ?? SystemLogRepository(resolvedDatabase);
    return AppDependencies._(
      database: resolvedDatabase,
      messages: SessionBoundMessageStore(resolvedMessages, resolvedSession),
      members: resolvedMembers,
      authentication:
          authentication ??
          MemberAuthenticator(
            database: resolvedDatabase,
            members: resolvedMembers,
          ),
      session: resolvedSession,
      workspace: workspace ?? WorkspaceRepository(resolvedDatabase),
      handovers: handovers ?? HandoverRepository(resolvedDatabase),
      home: SessionBoundHomeStore(resolvedHome, resolvedSession),
      systemLog: SessionBoundSystemLogStore(resolvedSystemLog, resolvedSession),
      tasks: tasks ?? TaskRepository(resolvedDatabase),
      ownsDatabase: database == null,
    );
  }

  /// Shared database connection owner.
  final AppDatabase database;

  /// Message persistence and revision operations.
  final MessageStore messages;

  /// Internal identity lifecycle persistence.
  final MemberStore members;

  /// Persisted member authentication and global rate limiting.
  final MemberAuthentication authentication;

  /// Ephemeral active identity and timeout-based revocation.
  final MemberSession session;

  /// Conversation and membership persistence.
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

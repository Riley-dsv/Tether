import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:note_app/database/database_factory_provider.dart';
import 'package:note_app/database/migrations/app_migrations.dart';
import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';

/// Lazily opened SQLite database owned by the application composition root.
///
/// A single instance caches one connection. Foreign keys, WAL, secure deletion,
/// and lock timeout behavior are configured consistently for mobile and FFI.
class AppDatabase {
  /// Creates a database wrapper.
  ///
  /// [factory] and [path] are injectable so tests can use an in-memory FFI
  /// database without mutating the device database.
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? defaultDatabaseFactory(),
      _path = path;

  final DatabaseFactory _factory;
  final String? _path;
  Database? _database;

  /// Returns the cached connection, opening and migrating it on first access.
  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final path =
        _path ?? p.join(await _factory.getDatabasesPath(), 'tether.db');
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppMigrations.currentVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          await db.rawQuery('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
          await db.rawQuery('PRAGMA secure_delete = ON');
          // Android classifies busy_timeout as a row-returning pragma and
          // rejects it through execute(). rawQuery works on Android and FFI.
          await db.rawQuery('PRAGMA busy_timeout = 3000');
        },
        onCreate: (db, version) async {
          await db.transaction((txn) async {
            await txn.execute(MessageTables.createMembers);
            await txn.execute(MessageTables.createConversations);
            await txn.execute(MessageTables.createConversationMembers);
            await txn.execute(MessageTables.createGeneralConversationIndex);
            await txn.insert('conversations', {
              'id': MessageTables.generalConversationId,
              'title': 'General',
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'scope': 'general',
            });
            await txn.execute(MessageTables.createMessageEntities);
            await txn.execute(MessageTables.createMessageRecipients);
            await txn.execute(MessageTables.createHandovers);
            await txn.execute(MessageTables.createHandoverRecipients);
            await txn.execute(MessageTables.createHandoverItems);
            await txn.execute(MessageTables.createHandoverReceipts);
            await txn.execute(MessageTables.createSystemEvents);
            await txn.execute(MessageTables.createTasks);
            await txn.execute(MessageTables.createTaskAssignees);
            await txn.execute(MessageTables.createTaskEventIndex);
            await txn.execute(MessageTables.createEncryptedRevisions);
            await txn.execute(MessageTables.createPins);
            await txn.execute(MessageTables.createReceipts);
            for (final index in MessageTables.indexes) {
              await txn.execute(index);
            }
            for (final trigger in MessageTables.integrityTriggers) {
              await txn.execute(trigger);
            }
          });
        },
        onUpgrade: (db, oldVersion, newVersion) =>
            runMigrations(db, oldVersion, newVersion, AppMigrations.all),
      ),
    );
  }

  /// Closes the cached connection and permits a later clean reopen.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Version 13 — persists the global authentication failure budget.
///
/// The singleton row deliberately spans all members, preventing an attacker
/// from resetting throttling by switching identities or restarting the app.
class MigrationV13 implements DatabaseMigration {
  const MigrationV13();

  @override
  int get targetVersion => 13;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE authentication_security (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        blocked_until TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await txn.insert('authentication_security', {
      'id': 1,
      'failed_attempts': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

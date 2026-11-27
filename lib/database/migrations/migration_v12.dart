import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Version 12 — adds optional per-member PIN verifiers.
///
/// Stores a salted PBKDF2 verifier and its work factor, never the PIN itself.
/// Existing members keep all three columns null so the application can offer
/// PIN setup at their next identity selection without blocking migration.
class MigrationV12 implements DatabaseMigration {
  const MigrationV12();

  @override
  int get targetVersion => 12;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute('ALTER TABLE members ADD COLUMN pin_hash TEXT');
    await txn.execute('ALTER TABLE members ADD COLUMN pin_salt TEXT');
    await txn.execute('ALTER TABLE members ADD COLUMN pin_iterations INTEGER');
  }
}

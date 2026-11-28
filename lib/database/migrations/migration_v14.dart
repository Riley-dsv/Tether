import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Version 14 — versions PIN derivation and introduces Argon2id parameters.
///
/// Existing version-one rows are explicitly marked as PBKDF2-SHA256. They are
/// still verifiable and are upgraded to Argon2id after successful PIN entry.
class MigrationV14 implements DatabaseMigration {
  const MigrationV14();

  @override
  int get targetVersion => 14;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(
      "ALTER TABLE members ADD COLUMN pin_kdf TEXT NOT NULL DEFAULT 'pbkdf2-sha256'",
    );
    await txn.execute(
      'ALTER TABLE members ADD COLUMN pin_version INTEGER NOT NULL DEFAULT 1',
    );
    await txn.execute('ALTER TABLE members ADD COLUMN pin_memory INTEGER');
    await txn.execute('ALTER TABLE members ADD COLUMN pin_parallelism INTEGER');
  }
}

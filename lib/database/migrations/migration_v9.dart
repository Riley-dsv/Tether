import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Version 9 — changes member removal into archival.
///
/// Adds nullable `members.deleted_at`. Active-member queries can now hide a
/// profile without deleting it, preserving authorship, recipients, receipts,
/// and other historical foreign-key relationships.
class MigrationV9 implements DatabaseMigration {
  const MigrationV9();

  @override
  int get targetVersion => 9;

  @override
  Future<void> migrate(Transaction txn) =>
      txn.execute('ALTER TABLE members ADD COLUMN deleted_at TEXT');
}

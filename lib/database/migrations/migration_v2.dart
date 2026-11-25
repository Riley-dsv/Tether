import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Version 2 — removes the prototype's predefined workspace.
///
/// Version 1 contained only bundled members, conversations, messages, pins,
/// and receipts used to demonstrate the prototype. This migration deliberately
/// clears those related tables in foreign-key-safe order so upgraded installs
/// start without fake identities or content.
///
/// This is the only intentionally destructive migration. It must remain in the
/// registry so a database still at version 1 can reach every later schema.
class MigrationV2 implements DatabaseMigration {
  const MigrationV2();
  @override
  int get targetVersion => 2;

  @override
  Future<void> migrate(Transaction txn) async {
    // Version 1 only contained the prototype's seeded workspace.
    await txn.delete('message_receipts');
    await txn.delete('message_pins');
    await txn.delete('message_revisions');
    await txn.delete('conversation_members');
    await txn.delete('conversations');
    await txn.delete('members');
  }
}

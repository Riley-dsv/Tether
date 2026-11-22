import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

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

import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

/// Version 4 — adds targeted sharing and traceable message transfers.
///
/// Extends each message entity with `visibility` and `source_message_id`, then
/// creates the many-to-many recipient table, its lookup index, and its integrity
/// trigger. Existing messages default to `shared`, preserving their prior
/// audience rather than making them unexpectedly private.
class MigrationV4 implements DatabaseMigration {
  const MigrationV4();
  @override
  int get targetVersion => 4;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(
      "ALTER TABLE message_entities ADD COLUMN visibility TEXT NOT NULL DEFAULT 'shared' CHECK (visibility IN ('private', 'group', 'shared'))",
    );
    await txn.execute(
      'ALTER TABLE message_entities ADD COLUMN source_message_id TEXT REFERENCES message_entities(id)',
    );
    await txn.execute(MessageTables.createMessageRecipients);
    await txn.execute(
      'CREATE INDEX idx_recipients_member ON message_recipients(member_id, logical_id)',
    );
    await txn.execute(MessageTables.integrityTriggers[3]);
  }
}

import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

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

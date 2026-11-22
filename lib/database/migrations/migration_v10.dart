import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV10 implements DatabaseMigration {
  const MigrationV10();

  @override
  int get targetVersion => 10;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(
      "ALTER TABLE conversations ADD COLUMN scope TEXT NOT NULL DEFAULT 'group' CHECK (scope IN ('general', 'group'))",
    );
    await txn.execute(MessageTables.createGeneralConversationIndex);
    final now = DateTime.now().toUtc().toIso8601String();
    await txn.insert('conversations', {
      'id': MessageTables.generalConversationId,
      'title': 'General',
      'created_at': now,
      'scope': 'general',
    });
    await txn.rawInsert(
      '''
      INSERT INTO conversation_members (conversation_id, member_id, joined_at)
      SELECT ?, id, ? FROM members WHERE deleted_at IS NULL
    ''',
      [MessageTables.generalConversationId, now],
    );
  }
}

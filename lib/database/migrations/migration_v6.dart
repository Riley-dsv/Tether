import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV6 implements DatabaseMigration {
  const MigrationV6();
  @override
  int get targetVersion => 6;

  @override
  Future<void> migrate(Transaction txn) async {
    // Frozen v6 schema: never replace this with the current table definition.
    await txn.execute('''
      CREATE TABLE system_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id TEXT REFERENCES conversations(id),
        actor_id TEXT REFERENCES members(id),
        event_type TEXT NOT NULL,
        summary TEXT NOT NULL,
        is_technical INTEGER NOT NULL DEFAULT 0 CHECK (is_technical IN (0, 1)),
        related_message_id TEXT REFERENCES message_entities(id),
        related_handover_id TEXT REFERENCES handovers(id),
        created_at TEXT NOT NULL
      )
    ''');
    await txn.insert('system_events', {
      'event_type': 'database_upgraded',
      'summary': 'Local database upgraded',
      'is_technical': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

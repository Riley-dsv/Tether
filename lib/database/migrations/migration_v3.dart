import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

/// Version 3 — separates logical messages from their immutable revisions.
///
/// Adds `message_entities`, backfills one stable entity for every existing
/// logical message, and installs integrity triggers for revisions, pins, and
/// receipts. The earliest revision timestamp becomes the entity creation time.
/// Existing message content and revision history are preserved.
class MigrationV3 implements DatabaseMigration {
  const MigrationV3();
  @override
  int get targetVersion => 3;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(MessageTables.createMessageEntitiesV3);
    await txn.rawInsert('''
      INSERT OR IGNORE INTO message_entities (id, conversation_id, created_at)
      SELECT logical_id, conversation_id, MIN(created_at)
      FROM message_revisions GROUP BY logical_id, conversation_id
    ''');
    for (final trigger in MessageTables.integrityTriggers.take(3)) {
      await txn.execute(trigger);
    }
  }
}

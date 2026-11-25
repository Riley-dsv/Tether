import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

/// Version 8 — connects task activity to the system log.
///
/// Adds the optional `related_task_id` foreign key to `system_events` and an
/// index for task-linked event queries. The column check makes the transition
/// tolerant of early development databases that already received the column.
class MigrationV8 implements DatabaseMigration {
  const MigrationV8();
  @override
  int get targetVersion => 8;

  @override
  Future<void> migrate(Transaction txn) async {
    final columns = await txn.rawQuery("PRAGMA table_info('system_events')");
    if (!columns.any((column) => column['name'] == 'related_task_id')) {
      await txn.execute(
        'ALTER TABLE system_events ADD COLUMN related_task_id TEXT REFERENCES tasks(id)',
      );
    }
    await txn.execute(MessageTables.createTaskEventIndex);
  }
}

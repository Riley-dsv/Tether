import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV7 implements DatabaseMigration {
  const MigrationV7();
  @override
  int get targetVersion => 7;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(MessageTables.createTasks);
    await txn.execute(MessageTables.createTaskAssignees);
  }
}

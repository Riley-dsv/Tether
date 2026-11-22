import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV9 implements DatabaseMigration {
  const MigrationV9();

  @override
  int get targetVersion => 9;

  @override
  Future<void> migrate(Transaction txn) =>
      txn.execute('ALTER TABLE members ADD COLUMN deleted_at TEXT');
}

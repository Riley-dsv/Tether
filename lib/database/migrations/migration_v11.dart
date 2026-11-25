import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV11 implements DatabaseMigration {
  const MigrationV11();

  @override
  int get targetVersion => 11;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(
      'ALTER TABLE message_revisions ADD COLUMN content_ciphertext TEXT',
    );
    await txn.execute(
      'ALTER TABLE message_revisions ADD COLUMN content_nonce TEXT',
    );
    await txn.execute(
      'ALTER TABLE message_revisions ADD COLUMN content_mac TEXT',
    );
    await txn.execute(
      'ALTER TABLE message_revisions ADD COLUMN encryption_version INTEGER NOT NULL DEFAULT 0',
    );
  }
}

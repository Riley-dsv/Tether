import 'package:note_app/database/migrations/database_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Version 11 — prepares message revisions for authenticated encryption.
///
/// Adds Base64 ciphertext, nonce, authentication tag, and format-version
/// columns. Existing rows remain marked with encryption version zero during the
/// schema transaction; `MessageRepository.prepare` subsequently encrypts them,
/// clears their plaintext, truncates the WAL, and vacuums free pages once the
/// platform-protected key is available.
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

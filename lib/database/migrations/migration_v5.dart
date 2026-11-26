import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/tables/message_tables.dart';
import 'package:sqflite/sqflite.dart';

/// Version 5 — introduces structured handovers.
///
/// Creates the handover root table plus recipient, checklist-item, and read
/// receipt tables. No existing rows are rewritten; the feature begins empty on
/// upgraded installations.
class MigrationV5 implements DatabaseMigration {
  const MigrationV5();
  @override
  int get targetVersion => 5;

  @override
  Future<void> migrate(Transaction txn) async {
    await txn.execute(MessageTables.createHandovers);
    await txn.execute(MessageTables.createHandoverRecipients);
    await txn.execute(MessageTables.createHandoverItems);
    await txn.execute(MessageTables.createHandoverReceipts);
  }
}

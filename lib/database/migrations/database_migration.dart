import 'package:sqflite/sqflite.dart';

/// One atomic transition to [targetVersion].
///
/// Released migrations are append-only history and must never be edited to
/// match a newer schema. Add another implementation instead.
abstract interface class DatabaseMigration {
  /// Schema version produced after [migrate] succeeds.
  int get targetVersion;

  /// Applies the transition inside a SQLite transaction.
  Future<void> migrate(Transaction transaction);
}

/// Applies migrations in ascending version order.
///
/// Each target version must be unique. Only versions in `(oldVersion,
/// newVersion]` run, making the function safe for incremental upgrades.
Future<void> runMigrations(
  Database database,
  int oldVersion,
  int newVersion,
  List<DatabaseMigration> migrations,
) async {
  final ordered = [...migrations]
    ..sort((left, right) => left.targetVersion.compareTo(right.targetVersion));
  for (var index = 1; index < ordered.length; index++) {
    if (ordered[index - 1].targetVersion == ordered[index].targetVersion) {
      throw StateError(
        'Duplicate database migration for version ${ordered[index].targetVersion}',
      );
    }
  }
  final pending = ordered.where(
    (migration) =>
        migration.targetVersion > oldVersion &&
        migration.targetVersion <= newVersion,
  );
  for (final migration in pending) {
    await database.transaction(migration.migrate);
  }
}

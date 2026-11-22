import 'package:sqflite/sqflite.dart';

abstract interface class DatabaseMigration {
  int get targetVersion;
  Future<void> migrate(Transaction transaction);
}

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

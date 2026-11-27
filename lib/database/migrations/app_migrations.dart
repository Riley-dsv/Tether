import 'package:note_app/database/migrations/database_migration.dart';
import 'package:note_app/database/migrations/migration_v2.dart';
import 'package:note_app/database/migrations/migration_v3.dart';
import 'package:note_app/database/migrations/migration_v4.dart';
import 'package:note_app/database/migrations/migration_v5.dart';
import 'package:note_app/database/migrations/migration_v6.dart';
import 'package:note_app/database/migrations/migration_v7.dart';
import 'package:note_app/database/migrations/migration_v8.dart';
import 'package:note_app/database/migrations/migration_v9.dart';
import 'package:note_app/database/migrations/migration_v10.dart';
import 'package:note_app/database/migrations/migration_v11.dart';
import 'package:note_app/database/migrations/migration_v12.dart';

/// Ordered registry of every released database migration.
///
/// [all] must remain strictly increasing; [currentVersion] is derived from the
/// final entry so version declarations cannot drift apart. Historical classes
/// remain executable upgrade paths: removing one would prevent installations
/// on that older version from advancing to the current schema.
abstract final class AppMigrations {
  /// Complete append-only migration chain.
  static const List<DatabaseMigration> all = [
    MigrationV2(),
    MigrationV3(),
    MigrationV4(),
    MigrationV5(),
    MigrationV6(),
    MigrationV7(),
    MigrationV8(),
    MigrationV9(),
    MigrationV10(),
    MigrationV11(),
    MigrationV12(),
  ];

  /// Schema version expected by the current application.
  static int get currentVersion => all.last.targetVersion;
}

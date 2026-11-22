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

abstract final class AppMigrations {
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
  ];

  static int get currentVersion => all.last.targetVersion;
}

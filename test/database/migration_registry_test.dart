import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/migrations/app_migrations.dart';

void main() {
  group('migration registry', () {
    test('versions are unique and strictly increasing', () {
      final versions = AppMigrations.all
          .map((migration) => migration.targetVersion)
          .toList();

      expect(versions, orderedEquals([...versions]..sort()));
      expect(versions.toSet(), hasLength(versions.length));
    });

    test('current version comes from the final migration', () {
      expect(
        AppMigrations.currentVersion,
        AppMigrations.all.last.targetVersion,
      );
      expect(AppMigrations.currentVersion, 12);
    });
  });
}

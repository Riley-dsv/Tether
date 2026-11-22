import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late WorkspaceRepository repository;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = WorkspaceRepository(database);
  });

  tearDown(() => database.close());

  group('general conversation', () {
    test('exists once and automatically includes new members', () async {
      final initial = await repository.conversations();
      expect(
        initial.where((conversation) => conversation.isGeneral),
        hasLength(1),
      );

      final alice = await repository.createMember('Alice');
      final morgan = await repository.createMember('Morgan');
      final general = (await repository.conversations()).singleWhere(
        (conversation) => conversation.isGeneral,
      );

      expect(
        general.members.map((member) => member.id),
        containsAll([alice.id, morgan.id]),
      );
    });
  });

  group('member lifecycle', () {
    test(
      'rename preserves identity and archive removes active profile',
      () async {
        final member = await repository.createMember('Morgan');
        final renamed = await repository.renameMember(
          memberId: member.id,
          displayName: 'Morgan Updated',
        );

        expect(renamed.id, member.id);
        expect(renamed.name, 'Morgan Updated');

        await repository.archiveMember(member.id);

        expect(
          (await repository.members()).map((item) => item.id),
          isNot(contains(member.id)),
        );
        final general = (await repository.conversations()).singleWhere(
          (conversation) => conversation.isGeneral,
        );
        expect(
          general.members.map((item) => item.id),
          isNot(contains(member.id)),
        );
      },
    );
  });
}

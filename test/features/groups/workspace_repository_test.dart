import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late WorkspaceRepository repository;
  late MemberRepository members;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = WorkspaceRepository(database);
    members = MemberRepository(database);
  });

  tearDown(() => database.close());

  group('general conversation', () {
    test('exists once and automatically includes new members', () async {
      final initial = await repository.conversations();
      expect(
        initial.where((conversation) => conversation.isGeneral),
        hasLength(1),
      );

      final alice = await members.createMember('Alice');
      final morgan = await members.createMember('Morgan');
      final general = (await repository.conversations()).singleWhere(
        (conversation) => conversation.isGeneral,
      );

      expect(
        general.members.map((member) => member.id),
        containsAll([alice.id, morgan.id]),
      );
    });
  });
}

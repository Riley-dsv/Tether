import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/members/member_pin.dart';
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
    members = MemberRepository(
      database,
      pinCodec: MemberPinCodec(
        iterations: 10,
        memory: 32,
        parallelism: 1,
        runInBackground: false,
        createSalt: () => List<int>.filled(16, 7),
      ),
    );
  });

  tearDown(() => database.close());

  group('general conversation', () {
    test('exists once and automatically includes new members', () async {
      final initial = await repository.conversations();
      expect(
        initial.where((conversation) => conversation.isGeneral),
        hasLength(1),
      );

      final alice = await members.createMember('Alice', pin: '1234');
      final morgan = await members.createMember('Morgan', pin: '1234');
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

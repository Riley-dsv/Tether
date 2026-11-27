import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late MemberRepository members;
  late WorkspaceRepository workspace;

  setUp(() {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    members = MemberRepository(database);
    workspace = WorkspaceRepository(database);
  });

  tearDown(() => database.close());

  test('create trims the name and joins the general conversation', () async {
    final member = await members.createMember('  Morgan  ');
    final general = (await workspace.conversations()).singleWhere(
      (conversation) => conversation.isGeneral,
    );

    expect(member.name, 'Morgan');
    expect(general.members.map((item) => item.id), contains(member.id));
  });

  test('empty names are rejected before persistence', () async {
    await expectLater(
      members.createMember('   '),
      throwsA(isA<ArgumentError>()),
    );
    expect(await members.members(), isEmpty);
  });

  test('rename preserves identity and archive keeps history', () async {
    final member = await members.createMember('Morgan');
    final renamed = await members.renameMember(
      memberId: member.id,
      displayName: 'Morgan Updated',
    );

    expect(renamed.id, member.id);
    expect(renamed.name, 'Morgan Updated');

    await members.archiveMember(member.id);

    expect(
      (await members.members()).map((item) => item.id),
      isNot(contains(member.id)),
    );
    final db = await database.database;
    final stored = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [member.id],
    );
    expect(stored, hasLength(1));
    expect(stored.single['deleted_at'], isNotNull);
  });

  test('renaming or archiving an inactive member fails', () async {
    final member = await members.createMember('Morgan');
    await members.archiveMember(member.id);

    await expectLater(
      members.renameMember(memberId: member.id, displayName: 'Other'),
      throwsStateError,
    );
    await expectLater(members.archiveMember(member.id), throwsStateError);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/members/member_pin.dart';
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
    members = MemberRepository(
      database,
      pinCodec: MemberPinCodec(
        iterations: 10,
        runInBackground: false,
        createSalt: () => List<int>.generate(16, (index) => index),
      ),
    );
    workspace = WorkspaceRepository(database);
  });

  tearDown(() => database.close());

  test('create trims the name and joins the general conversation', () async {
    final member = await members.createMember('  Morgan  ', pin: '1234');
    final general = (await workspace.conversations()).singleWhere(
      (conversation) => conversation.isGeneral,
    );

    expect(member.name, 'Morgan');
    expect(member.hasPin, isTrue);
    expect(general.members.map((item) => item.id), contains(member.id));
  });

  test('stores a salted verifier rather than the plaintext PIN', () async {
    final member = await members.createMember('Morgan', pin: '2468');
    final db = await database.database;
    final row = (await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [member.id],
    )).single;

    expect(row['pin_hash'], isNot('2468'));
    expect(row['pin_salt'], isNotNull);
    expect(row['pin_iterations'], 10);
    expect(await members.verifyPin(memberId: member.id, pin: '2468'), isTrue);
    expect(await members.verifyPin(memberId: member.id, pin: '1111'), isFalse);
  });

  test('an existing member can defer and set a PIN later', () async {
    final db = await database.database;
    await db.insert('members', {
      'id': 'legacy_member',
      'display_name': 'Legacy',
      'created_at': DateTime.utc(2026).toIso8601String(),
    });

    final legacy = (await members.members()).single;
    expect(legacy.hasPin, isFalse);
    expect(await members.verifyPin(memberId: legacy.id, pin: '1234'), isFalse);

    await members.setPin(memberId: legacy.id, pin: '9876');

    expect((await members.members()).single.hasPin, isTrue);
    expect(await members.verifyPin(memberId: legacy.id, pin: '9876'), isTrue);
  });

  test('rejects PINs outside the numeric policy', () async {
    for (final pin in ['123', '1234567890123', '12ab']) {
      await expectLater(
        members.createMember('Morgan', pin: pin),
        throwsA(isA<ArgumentError>()),
      );
    }
  });

  test('empty names are rejected before persistence', () async {
    await expectLater(
      members.createMember('   ', pin: '1234'),
      throwsA(isA<ArgumentError>()),
    );
    expect(await members.members(), isEmpty);
  });

  test('rename preserves identity and archive keeps history', () async {
    final member = await members.createMember('Morgan', pin: '1234');
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
    final member = await members.createMember('Morgan', pin: '1234');
    await members.archiveMember(member.id);

    await expectLater(
      members.renameMember(memberId: member.id, displayName: 'Other'),
      throwsStateError,
    );
    await expectLater(members.archiveMember(member.id), throwsStateError);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/members/member_credential_backup.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late MemberRepository members;
  var saltSequence = 1;

  MemberPinCodec codec() => MemberPinCodec(
    iterations: 10,
    runInBackground: false,
    createSalt: () => List<int>.filled(16, saltSequence++),
  );

  setUp(() {
    saltSequence = 1;
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    members = MemberRepository(database, pinCodec: codec());
  });

  tearDown(() => database.close());

  test('Unknown cannot create a PIN-backed member', () async {
    for (final name in ['Unknown', 'anonymous', 'Collective']) {
      await expectLater(
        members.createMember(name, pin: '1234'),
        throwsArgumentError,
      );
    }
    expect(await members.members(), isEmpty);
  });

  test('Unknown cannot receive a PIN through an update', () async {
    await expectLater(
      members.setPin(memberId: 'unknown', pin: '1234'),
      throwsStateError,
    );
    expect(await members.members(), isEmpty);
  });

  test('Unknown cannot receive credentials through import', () async {
    final service = MemberCredentialBackupService(database);

    await expectLater(
      service.restoreCredentials(const [
        MemberCredentialBackup(
          memberId: 'unknown',
          hash: 'AQ==',
          salt: 'Ag==',
          iterations: 10,
        ),
      ]),
      throwsStateError,
    );
  });

  test(
    'PIN is never plaintext and identical PINs use different salts',
    () async {
      final alice = await members.createMember('Alice', pin: '1234');
      final morgan = await members.createMember('Morgan', pin: '1234');
      final db = await database.database;
      final rows = await db.query(
        'members',
        columns: ['id', 'pin_hash', 'pin_salt'],
        where: 'id IN (?, ?)',
        whereArgs: [alice.id, morgan.id],
        orderBy: 'id',
      );

      expect(rows.every((row) => row['pin_hash'] != '1234'), isTrue);
      expect(rows.map((row) => row['pin_salt']).toSet(), hasLength(2));
      expect(rows.map((row) => row['pin_hash']).toSet(), hasLength(2));
    },
  );

  test('logs never contain PIN values', () async {
    final alice = await members.createMember('Alice', pin: '1234');
    await members.setPin(memberId: alice.id, pin: '987654');

    final events = await SystemLogRepository(
      database,
    ).list(includeTechnical: true);
    final serialized = events.map((event) => event.summary).join('\n');
    expect(serialized, isNot(contains('1234')));
    expect(serialized, isNot(contains('987654')));
  });

  test('backup and restoration preserve credential verification', () async {
    final alice = await members.createMember('Alice', pin: '2468');
    final backup = await MemberCredentialBackupService(
      database,
    ).exportCredentials();
    expect(backup, hasLength(1));

    final restorePath =
        '/tmp/tether_restore_${DateTime.now().microsecondsSinceEpoch}.db';
    addTearDown(() => databaseFactoryFfi.deleteDatabase(restorePath));
    final restoredDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: restorePath,
    );
    addTearDown(restoredDatabase.close);
    final restoredDb = await restoredDatabase.database;
    await restoredDb.insert('members', {
      'id': alice.id,
      'display_name': alice.name,
      'created_at': DateTime.utc(2026).toIso8601String(),
    });
    await MemberCredentialBackupService(
      restoredDatabase,
    ).restoreCredentials(backup);
    final restoredMembers = MemberRepository(
      restoredDatabase,
      pinCodec: codec(),
    );

    expect(
      await restoredMembers.verifyPin(memberId: alice.id, pin: '2468'),
      isTrue,
    );
    expect(
      await restoredMembers.verifyPin(memberId: alice.id, pin: '0000'),
      isFalse,
    );
  });

  test('database migration preserves existing credential verifiers', () async {
    final path =
        '/tmp/tether_credentials_${DateTime.now().microsecondsSinceEpoch}.db';
    addTearDown(() => databaseFactoryFfi.deleteDatabase(path));
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE members (
              id TEXT PRIMARY KEY,
              display_name TEXT NOT NULL,
              created_at TEXT NOT NULL,
              deleted_at TEXT,
              pin_hash TEXT,
              pin_salt TEXT,
              pin_iterations INTEGER
            )
          ''');
          await db.insert('members', {
            'id': 'alice',
            'display_name': 'Alice',
            'created_at': DateTime.utc(2026).toIso8601String(),
            'pin_hash': 'AQI=',
            'pin_salt': 'AwQ=',
            'pin_iterations': 10,
          });
        },
      ),
    );
    await old.close();

    final migrated = AppDatabase(factory: databaseFactoryFfi, path: path);
    addTearDown(migrated.close);
    final db = await migrated.database;
    final row = (await db.query('members')).single;

    expect(row['pin_hash'], 'AQI=');
    expect(row['pin_salt'], 'AwQ=');
    expect(row['pin_iterations'], 10);
    expect(await db.query('authentication_security'), hasLength(1));
  });
}

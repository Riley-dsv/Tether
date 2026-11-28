import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/members/attribution_identity.dart';
import 'package:note_app/features/members/member_authenticator.dart';
import 'package:note_app/features/members/member_pin.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late MemberRepository members;
  late SystemMember alice;
  late SystemMember morgan;
  final now = DateTime.utc(2026, 11, 28, 12);

  MemberAuthenticator authenticator({int maximumAttempts = 5}) =>
      MemberAuthenticator(
        database: database,
        members: members,
        now: () => now,
        maximumAttempts: maximumAttempts,
      );

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    members = MemberRepository(
      database,
      pinCodec: MemberPinCodec(
        iterations: 10,
        memory: 32,
        parallelism: 1,
        runInBackground: false,
        createSalt: () => List<int>.filled(16, 3),
      ),
    );
    alice = await members.createMember('Alice', pin: '1234');
    morgan = await members.createMember('Morgan', pin: '5678');
  });

  tearDown(() => database.close());

  test('correct PIN grants access and incorrect PIN does not', () async {
    final auth = authenticator();

    expect(
      await auth.authenticate(MemberAttribution(alice), '0000'),
      AuthenticationResult.denied,
    );
    expect(
      await auth.authenticate(MemberAttribution(alice), '1234'),
      AuthenticationResult.granted,
    );
  });

  test('PIN change requires current authentication', () async {
    final auth = authenticator();

    expect(
      await auth.changePin(
        identity: MemberAttribution(alice),
        currentPin: '0000',
        newPin: '9999',
      ),
      AuthenticationResult.denied,
    );
    expect(await members.verifyPin(memberId: alice.id, pin: '9999'), isFalse);

    expect(
      await auth.changePin(
        identity: MemberAttribution(alice),
        currentPin: '1234',
        newPin: '9999',
      ),
      AuthenticationResult.granted,
    );
    expect(await members.verifyPin(memberId: alice.id, pin: '9999'), isTrue);
  });

  test('failed attempts persist across authenticator restarts', () async {
    expect(
      await authenticator(
        maximumAttempts: 2,
      ).authenticate(MemberAttribution(alice), '0000'),
      AuthenticationResult.denied,
    );

    expect(
      await authenticator(
        maximumAttempts: 2,
      ).authenticate(MemberAttribution(alice), '0000'),
      AuthenticationResult.rateLimited,
    );
    expect(
      await authenticator(
        maximumAttempts: 2,
      ).authenticate(MemberAttribution(alice), '1234'),
      AuthenticationResult.rateLimited,
    );
  });

  test('rate limiting cannot be bypassed by switching members', () async {
    final auth = authenticator(maximumAttempts: 2);

    expect(
      await auth.authenticate(MemberAttribution(alice), '0000'),
      AuthenticationResult.denied,
    );
    expect(
      await auth.authenticate(MemberAttribution(morgan), '0000'),
      AuthenticationResult.rateLimited,
    );
    expect(
      await auth.authenticate(MemberAttribution(morgan), '5678'),
      AuthenticationResult.rateLimited,
    );
  });

  test(
    'concurrent authentication requests cannot bypass restrictions',
    () async {
      final auth = authenticator(maximumAttempts: 3);
      final results = await Future.wait(
        List.generate(
          8,
          (_) => auth.authenticate(MemberAttribution(alice), '0000'),
        ),
      );

      expect(results, isNot(contains(AuthenticationResult.granted)));
      expect(
        results.where((result) => result == AuthenticationResult.denied),
        hasLength(2),
      );
      expect(
        results.where((result) => result == AuthenticationResult.rateLimited),
        hasLength(6),
      );
    },
  );

  test('archived members cannot open new sessions', () async {
    await members.archiveMember(alice.id);

    expect(
      await authenticator().authenticate(MemberAttribution(alice), '1234'),
      AuthenticationResult.denied,
    );
  });

  test('members without a PIN remain supported and request setup', () async {
    final db = await database.database;
    await db.insert('members', {
      'id': 'legacy',
      'display_name': 'Legacy',
      'created_at': now.toIso8601String(),
    });
    final legacy = (await members.members()).singleWhere(
      (member) => member.id == 'legacy',
    );

    expect(
      await authenticator().authenticate(MemberAttribution(legacy), ''),
      AuthenticationResult.requiresPinSetup,
    );
  });

  test('Unknown and collective attribution cannot authenticate', () async {
    final auth = authenticator();

    expect(
      await auth.authenticate(const UnknownAttribution(), '1234'),
      AuthenticationResult.notAuthenticatable,
    );
    expect(
      await auth.authenticate(CollectiveAttribution([alice, morgan]), '1234'),
      AuthenticationResult.notAuthenticatable,
    );
  });
}

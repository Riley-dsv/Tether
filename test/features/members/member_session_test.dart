import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/features/members/member_session.dart';
import 'package:note_app/features/members/system_member.dart';

void main() {
  final alice = SystemMember.fromStorage(id: 'alice', name: 'Alice');
  final morgan = SystemMember.fromStorage(id: 'morgan', name: 'Morgan');

  test('switching members revokes previous access', () {
    final session = MemberSession();
    final aliceLease = session.activate(alice);

    final morganLease = session.activate(morgan);

    expect(session.permits(aliceLease), isFalse);
    expect(session.permits(morganLease), isTrue);
  });

  test('switching to Unknown revokes private access', () {
    final session = MemberSession();
    final lease = session.activate(alice);

    session.useAnonymous();

    expect(session.isAnonymous, isTrue);
    expect(session.permits(lease), isFalse);
  });

  test('background timeout locks protected content', () {
    var now = DateTime.utc(2026, 11, 28, 12);
    final session = MemberSession(
      now: () => now,
      backgroundTimeout: const Duration(minutes: 2),
    );
    final lease = session.activate(alice);
    session.background();
    now = now.add(const Duration(minutes: 3));

    expect(session.resume(), isTrue);
    expect(session.isAnonymous, isTrue);
    expect(session.permits(lease), isFalse);
  });

  test('short background periods preserve the active session', () {
    var now = DateTime.utc(2026, 11, 28, 12);
    final session = MemberSession(
      now: () => now,
      backgroundTimeout: const Duration(minutes: 2),
    );
    final lease = session.activate(alice);
    session.background();
    now = now.add(const Duration(minutes: 1));

    expect(session.resume(), isFalse);
    expect(session.permits(lease), isTrue);
  });

  test('stale navigation leases cannot reopen protected screens', () {
    final session = MemberSession();
    final protectedRouteLease = session.activate(alice);

    session.useAnonymous();

    expect(session.permits(protectedRouteLease), isFalse);
  });
}

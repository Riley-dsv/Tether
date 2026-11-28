import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/features/members/attribution_identity.dart';
import 'package:note_app/features/members/system_member.dart';

void main() {
  final alice = SystemMember.fromStorage(id: 'alice', name: 'Alice');
  final morgan = SystemMember.fromStorage(id: 'morgan', name: 'Morgan');

  test('Unknown cannot own authentication credentials', () {
    const identity = UnknownAttribution();

    expect(identity.authenticatableMember, isNull);
  });

  test('collective attribution does not grant member authentication', () {
    final identity = CollectiveAttribution([alice, morgan]);

    expect(identity.members, containsAll([alice, morgan]));
    expect(identity.authenticatableMember, isNull);
  });

  test('only individual member attribution is authenticatable', () {
    final identity = MemberAttribution(alice);

    expect(identity.authenticatableMember, same(alice));
  });
}

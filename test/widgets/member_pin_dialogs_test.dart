import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/shared/widgets/members/member_pin_dialogs.dart';

void main() {
  testWidgets('new members require a matching valid PIN', (tester) async {
    MemberDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<MemberDraft>(
                context: context,
                builder: (_) => const CreateMemberDialog(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-name')), 'Morgan');
    await tester.enterText(find.byKey(const Key('member-pin')), '1234');
    await tester.enterText(
      find.byKey(const Key('member-pin-confirmation')),
      '9999',
    );
    await tester.pump();

    expect(find.text('PINs do not match'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('member-pin-confirmation')),
      '1234',
    );
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Morgan');
    expect(result?.pin, '1234');
  });

  testWidgets('unlock keeps the dialog open after an incorrect PIN', (
    tester,
  ) async {
    final member = SystemMember.fromStorage(
      id: 'morgan',
      name: 'Morgan',
      hasPin: true,
    );
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) => UnlockMemberDialog(
                  member: member,
                  verify: (pin) async => pin == '1234',
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unlock-member-pin')), '9999');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(find.byKey(const Key('unlock-member-pin')), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('legacy members can defer PIN setup', (tester) async {
    MissingPinChoice? result;
    final member = SystemMember.fromStorage(id: 'legacy', name: 'Legacy');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<MissingPinChoice>(
                context: context,
                builder: (_) => MissingMemberPinDialog(member: member),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(result, MissingPinChoice.later);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:note_app/shared/widgets/members/member_management_dialog.dart';

void main() {
  testWidgets('allows adding a member when the member list is empty', (
    tester,
  ) async {
    MemberManagementAction? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<MemberManagementAction>(
                context: context,
                builder: (_) => const MemberManagementDialog(members: []),
              );
            },
            child: const Text('Manage members'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Manage members'));
    await tester.pumpAndSettle();

    expect(find.text('No member profiles'), findsOneWidget);
    expect(find.text('Add member'), findsOneWidget);

    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();

    expect(result?.type, MemberManagementActionType.create);
    expect(result?.member, isNull);
  });
}

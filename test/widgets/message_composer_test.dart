import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/shared/widgets/messages/message_widgets.dart';

void main() {
  testWidgets('can explicitly change sender to Unknown', (tester) async {
    final morgan = SystemMember.fromStorage(id: 'morgan', name: 'Morgan');
    SystemMember? selected = morgan;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(
                controller: TextEditingController(),
                author: selected,
                members: [morgan],
                recipientIds: const {},
                onChooseRecipients: () {},
                onCreateMember: () {},
                onAuthorChanged: (member) => setState(() => selected = member),
                onSend: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('message-author-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-author-unknown')));
    await tester.pumpAndSettle();

    expect(selected, isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('message-current-author'))).data,
      'Unknown',
    );
  });
}

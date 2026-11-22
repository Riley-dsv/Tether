import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_dependencies.dart';
import 'package:note_app/app/tether_app.dart';
import 'package:note_app/database/app_database.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('member posts an attributed message in General', (tester) async {
    final databasePath = path.join(
      await getDatabasesPath(),
      'tether_integration_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final database = AppDatabase(path: databasePath);
    final workspace = WorkspaceRepository(database);
    final morgan = await workspace.createMember('Morgan');
    final dependencies = AppDependencies(database: database);

    await tester.pumpWidget(TetherApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-author-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('message-author-${morgan.id}')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Write a message…'),
      'Integration hello',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Integration hello'), findsOneWidget);
    expect(find.text('Morgan'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
    await databaseFactory.deleteDatabase(databasePath);
  });
}

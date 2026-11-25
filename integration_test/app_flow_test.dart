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
    addTearDown(() async {
      await database.close();
      await databaseFactory.deleteDatabase(databasePath);
    });
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
    await _pumpUntilFound(tester, find.text('Integration hello'));

    expect(find.text('Integration hello'), findsOneWidget);
    expect(find.text('Morgan'), findsWidgets);

    final db = await database.database;
    final stored = (await db.query(
      'message_revisions',
      orderBy: 'revision_id DESC',
      limit: 1,
    )).single;
    expect(stored['content'], '');
    expect(stored['encryption_version'], 1);
    expect(stored['content_ciphertext'], isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  const interval = Duration(milliseconds: 100);
  final attempts = timeout.inMilliseconds ~/ interval.inMilliseconds;
  for (var attempt = 0; attempt < attempts; attempt++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future<void>.delayed(interval));
    await tester.pump();
  }
  if (finder.evaluate().isEmpty) {
    throw TestFailure('Timed out waiting for $finder');
  }
}

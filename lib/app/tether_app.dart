import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_dependencies.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/features/messages/message_workspace_screen.dart';

/// Root Material application and dependency-lifetime boundary.
///
/// When [dependencies] is omitted, the widget creates and disposes the
/// production graph. Injected dependencies remain owned by the caller.
class TetherApp extends StatefulWidget {
  /// Creates the application with optional dependency overrides.
  const TetherApp({super.key, this.dependencies});

  /// Dependency graph override, primarily used by tests.
  final AppDependencies? dependencies;

  @override
  State<TetherApp> createState() => _TetherAppState();
}

class _TetherAppState extends State<TetherApp> {
  late final AppDependencies _dependencies;
  late final bool _ownsDependencies;

  @override
  void initState() {
    super.initState();
    _ownsDependencies = widget.dependencies == null;
    _dependencies = widget.dependencies ?? AppDependencies();
  }

  @override
  void dispose() {
    if (_ownsDependencies) _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tether',
    theme: buildAppTheme(),
    home: MessageWorkspaceScreen(
      messages: _dependencies.messages,
      members: _dependencies.members,
      workspace: _dependencies.workspace,
      handovers: _dependencies.handovers,
      home: _dependencies.home,
      systemLog: _dependencies.systemLog,
      tasks: _dependencies.tasks,
    ),
  );
}

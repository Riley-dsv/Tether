import 'package:note_app/features/groups/conversation.dart';
import 'package:note_app/features/handovers/handover.dart';
import 'package:note_app/features/home/home_summary.dart';
import 'package:note_app/features/system_log/system_event.dart';
import 'package:note_app/features/tasks/task.dart';
import 'package:note_app/shared/models/system_member.dart';

/// Ephemeral presentation state for the workspace screen.
///
/// Persistent data and operations remain behind store/controller contracts;
/// this object only describes what the UI is currently presenting.
class WorkspaceViewState {
  bool homeMode = true;
  bool loadingHome = false;
  String? homeError;
  HomeSummary homeSummary = const HomeSummary.empty();
  List<SystemMember> members = const [];
  List<Conversation> conversations = const [];
  Conversation? selected;
  SystemMember? currentAuthor;
  Set<String> recipientIds = {};
  bool loadingWorkspace = true;
  bool showSearch = false;
  bool handoverMode = false;
  List<Handover> handovers = const [];
  bool logMode = false;
  bool includeTechnicalEvents = false;
  List<SystemEvent> systemEvents = const [];
  bool taskMode = false;
  List<WorkspaceTask> tasks = const [];
}

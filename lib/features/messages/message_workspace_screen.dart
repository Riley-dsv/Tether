import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/features/groups/conversation.dart';
import 'package:note_app/features/groups/workspace_repository.dart';
import 'package:note_app/features/handovers/handover.dart';
import 'package:note_app/features/handovers/handover_repository.dart';
import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_controller.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/members/member_repository.dart';
import 'package:note_app/shared/widgets/handovers/handover_widgets.dart';
import 'package:note_app/shared/widgets/messages/message_widgets.dart';
import 'package:note_app/features/messages/workspace_view_state.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';
import 'package:note_app/features/system_log/system_log_view.dart';
import 'package:note_app/features/tasks/task.dart';
import 'package:note_app/features/tasks/task_repository.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/shared/widgets/home/home_view.dart';
import 'package:note_app/shared/widgets/members/member_management_dialog.dart';
import 'package:note_app/shared/widgets/tasks/task_widgets.dart';

part 'workspace_actions.dart';

/// Main adaptive workspace joining home, messages, tasks, and handovers.
///
/// The screen owns only ephemeral presentation state. Persistent mutations are
/// delegated to injected stores and [MessageController].
class MessageWorkspaceScreen extends StatefulWidget {
  /// Creates the workspace from its feature-level contracts.
  const MessageWorkspaceScreen({
    super.key,
    required this.messages,
    required this.members,
    required this.workspace,
    required this.handovers,
    required this.home,
    required this.systemLog,
    required this.tasks,
  });

  /// Encrypted message store.
  final MessageStore messages;

  /// Internal identity lifecycle store.
  final MemberStore members;

  /// Conversation and membership store.
  final WorkspaceStore workspace;

  /// Handover store.
  final HandoverStore handovers;

  /// Dashboard aggregation store.
  final HomeStore home;

  /// Cross-feature system log store.
  final SystemLogStore systemLog;

  /// Task and reminder store.
  final TaskStore tasks;

  @override
  State<MessageWorkspaceScreen> createState() => _MessageWorkspaceScreenState();
}

class _MessageWorkspaceScreenState extends State<MessageWorkspaceScreen> {
  final _composer = TextEditingController();
  final _search = TextEditingController();
  late final MessageController _messages;
  late final MemberStore _members;
  late final WorkspaceStore _workspace;
  late final HandoverStore _handoverRepository;
  late final HomeStore _homeRepository;
  late final SystemLogStore _systemLogRepository;
  late final TaskStore _taskRepository;
  final _view = WorkspaceViewState();

  @override
  void initState() {
    super.initState();
    _messages = MessageController(widget.messages)..addListener(_refresh);
    _members = widget.members;
    _workspace = widget.workspace;
    _handoverRepository = widget.handovers;
    _homeRepository = widget.home;
    _systemLogRepository = widget.systemLog;
    _taskRepository = widget.tasks;
    _loadWorkspace();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _update(VoidCallback update) {
    if (mounted) setState(update);
  }

  Future<void> _loadWorkspace({String? selectId}) async {
    try {
      await _messages.prepare();
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _view.loadingWorkspace = false;
        _view.workspaceError = exception.toString();
      });
      return;
    }
    final results = await Future.wait<Object>([
      _members.members(),
      _workspace.conversations(viewerId: _view.currentAuthor?.id),
    ]);
    final members = results[0] as List<SystemMember>;
    final conversations = results[1] as List<Conversation>;
    if (!mounted) return;
    final desiredId =
        selectId ??
        _view.selected?.id ??
        (conversations.isEmpty ? null : conversations.first.id);
    Conversation? selected;
    for (final conversation in conversations) {
      if (conversation.id == desiredId) selected = conversation;
    }
    setState(() {
      _view.members = members;
      _view.conversations = conversations;
      _view.selected = selected;
      _view.loadingWorkspace = false;
      _view.workspaceError = null;
      if (_view.currentAuthor != null &&
          !members.any((member) => member.id == _view.currentAuthor!.id)) {
        _view.currentAuthor = null;
      }
    });
    if (!_view.homeMode && _messages.conversationId != selected?.id) {
      await _messages.selectConversation(selected?.id);
    }
    if (_view.homeMode) await _loadHome();
  }

  @override
  void dispose() {
    _composer.dispose();
    _search.dispose();
    _messages
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  Future<void> _selectConversation(Conversation conversation) async {
    setState(() {
      _view.selected = conversation;
      _view.homeMode = false;
      _view.recipientIds = {};
      if (_view.currentAuthor != null &&
          !conversation.members.any(
            (member) => member.id == _view.currentAuthor!.id,
          )) {
        _view.currentAuthor = null;
      }
      _view.showSearch = false;
      _search.clear();
    });
    await _messages.selectConversation(conversation.id);
    if (_view.handoverMode) await _loadHandovers();
    if (_view.taskMode) await _loadTasks();
  }

  Future<void> _send() async {
    if (_view.selected == null) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    await _messages.send(
      text,
      _view.currentAuthor?.id,
      recipientIds: _view.recipientIds,
    );
    setState(() => _view.recipientIds = {});
    await _loadWorkspace(selectId: _view.selected!.id);
  }

  Future<void> _createMember({bool addToSelectedConversation = true}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CreateMemberDialog(),
    );
    if (name == null) return;
    final member = await _members.createMember(name);
    if (addToSelectedConversation && _view.selected != null) {
      await _workspace.addMemberToConversation(
        conversationId: _view.selected!.id,
        memberId: member.id,
      );
    }
    await _changeCurrentMember(member);
  }

  Future<void> _createConversation() async {
    final input = await showDialog<ConversationInput>(
      context: context,
      builder: (_) => CreateConversationDialog(members: _view.members),
    );
    if (input == null) return;
    final conversation = await _workspace.createConversation(
      title: input.title,
      memberIds: input.memberIds,
    );
    await _loadWorkspace(selectId: conversation.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_view.loadingWorkspace) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_view.workspaceError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Encrypted messages could not be unlocked.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _view.workspaceError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _view.loadingWorkspace = true);
                    _loadWorkspace();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) return _mobileLayout();
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                WorkspaceNavigation(
                  currentMember: _view.currentAuthor,
                  homeSelected: _view.homeMode,
                  onHome: _openHome,
                  onMessages: _openMessages,
                  pinnedOnly: _messages.pinnedOnly,
                  onPinnedToggle: _view.selected == null
                      ? null
                      : () {
                          setState(() {
                            _view.homeMode = false;
                            _view.handoverMode = false;
                            _view.taskMode = false;
                            _view.logMode = false;
                          });
                          _messages.togglePinnedFilter();
                        },
                  handoversSelected: _view.handoverMode,
                  onHandovers: _openHandovers,
                  tasksSelected: _view.taskMode,
                  onTasks: _openTasks,
                  logSelected: _view.logMode,
                  onSystemLog: _openSystemLog,
                ),
                ConversationList(
                  conversations: _view.conversations,
                  selectedId: _view.selected?.id,
                  unreadCount: _messages.unreadCount,
                  onSelected: _selectConversation,
                  onAdd: _createConversation,
                ),
                Expanded(child: _mainContent()),
                if (constraints.maxWidth >= 1250 && _view.selected != null)
                  SharedContextPanel(conversation: _view.selected!),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileLayout() => Scaffold(
    drawer: Drawer(
      backgroundColor: AppColors.paper,
      child: SafeArea(
        child: ConversationList(
          conversations: _view.conversations,
          selectedId: _view.selected?.id,
          unreadCount: _messages.unreadCount,
          onSelected: (conversation) {
            Navigator.pop(context);
            _selectConversation(conversation);
          },
          onAdd: _createConversation,
          mobile: true,
        ),
      ),
    ),
    appBar: AppBar(
      backgroundColor: const Color(0xFFFBFAF6),
      surfaceTintColor: Colors.transparent,
      titleSpacing: 4,
      title: Text(
        _view.homeMode ? 'Home' : _view.selected?.title ?? 'Tether',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      actions: [
        if (_view.selected != null && !_view.homeMode)
          IconButton(
            tooltip: _messages.pinnedOnly
                ? 'Show all messages'
                : 'Show pinned messages',
            onPressed: _messages.togglePinnedFilter,
            icon: Icon(
              _messages.pinnedOnly ? Icons.push_pin : Icons.push_pin_outlined,
            ),
          ),
        if (_view.selected != null && !_view.homeMode)
          IconButton(
            onPressed: () =>
                setState(() => _view.showSearch = !_view.showSearch),
            icon: Icon(_view.showSearch ? Icons.close : Icons.search),
          ),
      ],
    ),
    body: _mainContent(showHeader: false),
    bottomNavigationBar: NavigationBar(
      height: 64,
      selectedIndex: _view.logMode
          ? 4
          : _view.taskMode
          ? 3
          : _view.handoverMode
          ? 2
          : _view.homeMode
          ? 0
          : 1,
      onDestinationSelected: (index) {
        if (index == 4) {
          _openSystemLog();
        } else if (index == 3) {
          _openTasks();
        } else if (index == 2) {
          _openHandovers();
        } else if (index == 1) {
          _openMessages();
        } else if (index == 0) {
          _openHome();
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: Icon(Icons.move_to_inbox_outlined),
          label: 'Handovers',
        ),
        NavigationDestination(
          icon: Icon(Icons.task_alt_outlined),
          label: 'Tasks',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Log'),
      ],
    ),
  );

  Widget _mainContent({bool showHeader = true}) {
    if (_view.homeMode) {
      return HomeView(
        summary: _view.homeSummary,
        members: _view.members,
        currentMember: _view.currentAuthor,
        loading: _view.loadingHome,
        error: _view.homeError,
        onMemberChanged: _changeCurrentMember,
        onMessages: _openMessages,
        onHandovers: _openHandovers,
        onTasks: _openTasks,
        onCreateMember: _createMember,
        onCreateConversation: _createConversation,
        onManageMembers: _manageMembers,
      );
    }
    if (_view.logMode) {
      return SystemLogView(
        events: _view.systemEvents,
        includeTechnical: _view.includeTechnicalEvents,
        onTechnicalChanged: (value) {
          setState(() => _view.includeTechnicalEvents = value);
          _loadSystemLog();
        },
        onBack: () => setState(() => _view.logMode = false),
      );
    }
    if (_view.selected == null) {
      return EmptyWorkspace(
        hasMembers: _view.members.isNotEmpty,
        onCreateMember: _createMember,
        onCreateConversation: _createConversation,
      );
    }
    if (_view.taskMode) {
      return TaskView(
        tasks: _view.tasks,
        onCreate: _createTask,
        onStatusChanged: _updateTaskStatus,
        onBack: () => setState(() => _view.taskMode = false),
      );
    }
    if (_view.handoverMode) {
      return HandoverView(
        handovers: _view.handovers,
        currentMemberId: _view.currentAuthor?.id,
        onCreate: _createHandover,
        onMarkRead: _markHandoverRead,
        onBack: () => setState(() => _view.handoverMode = false),
      );
    }
    return ColoredBox(
      color: const Color(0xFFFBFAF6),
      child: Column(
        children: [
          if (showHeader)
            ConversationHeader(
              conversation: _view.selected!,
              showSearch: _view.showSearch,
              searchController: _search,
              onSearchChanged: _messages.search,
              onToggleSearch: () => setState(() {
                _view.showSearch = !_view.showSearch;
                if (!_view.showSearch) {
                  _search.clear();
                  _messages.search('');
                }
              }),
            )
          else if (_view.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: _messages.search,
                decoration: const InputDecoration(
                  hintText: 'Search messages',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
          Expanded(child: _messageList()),
          MessageComposer(
            controller: _composer,
            author: _view.currentAuthor,
            members: _view.selected!.members,
            recipientIds: _view.recipientIds,
            onChooseRecipients: _chooseRecipients,
            onCreateMember: _createMember,
            onAuthorChanged: (author) {
              _changeCurrentMember(author);
            },
            onSend: _send,
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    if (_messages.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.error != null) {
      return Center(
        child: Text(
          'Could not load messages\n${_messages.error}',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_messages.messages.isEmpty) {
      return Center(
        child: Text(
          _messages.query.isNotEmpty
              ? 'No matching messages'
              : _messages.pinnedOnly
              ? 'No pinned messages'
              : 'No messages yet',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 240) {
          _messages.loadMore();
        }
        return false;
      },
      child: ListView.separated(
        reverse: true,
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width < 700 ? 12 : 30,
          20,
          MediaQuery.sizeOf(context).width < 700 ? 12 : 30,
          12,
        ),
        itemCount: _messages.messages.length + (_messages.loadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == _messages.messages.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final message = _messages.messages[index];
          return MessageCard(
            message: message,
            currentMemberId: _view.currentAuthor?.id,
            onPin: () => _messages.togglePin(message, _view.currentAuthor?.id),
            onSeen: _view.currentAuthor == null
                ? null
                : () => _messages.markSeen(message, _view.currentAuthor!.id),
            onEdit: () => _editMessage(message),
            onDelete: () => _deleteMessage(message),
            onHistory: () => _showHistory(message),
            onTransfer: () => _transferMessage(message),
          );
        },
      ),
    );
  }
}

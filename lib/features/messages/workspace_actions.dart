part of 'message_workspace_screen.dart';

extension _WorkspaceActions on _MessageWorkspaceScreenState {
  bool _ensureConversation() {
    if (_view.selected != null) return true;
    if (_view.conversations.isNotEmpty) {
      _view.selected = _view.conversations.first;
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create a conversation first.')),
    );
    return false;
  }

  Future<void> _openHome() async {
    _update(() {
      _view.homeMode = true;
      _view.handoverMode = false;
      _view.taskMode = false;
      _view.logMode = false;
    });
    await _loadHome();
  }

  Future<void> _openMessages() async {
    if (!_ensureConversation()) return;
    _update(() {
      _view.homeMode = false;
      _view.handoverMode = false;
      _view.taskMode = false;
      _view.logMode = false;
    });
    if (_view.selected == null) return;
    if (_messages.conversationId != _view.selected!.id) {
      await _messages.selectConversation(_view.selected!.id);
    } else if (_messages.pinnedOnly) {
      await _messages.togglePinnedFilter();
    } else if (_messages.messages.isEmpty) {
      await _messages.load(showLoading: true);
    }
  }

  Future<void> _changeCurrentMember(SystemMember? member) async {
    if (member?.id == _view.currentAuthor?.id) return;
    if (member != null) {
      final authorized = await _authorizeMember(member);
      if (authorized == null) return;
      member = authorized;
    }
    await _activateCurrentMember(member);
  }

  Future<SystemMember?> _authorizeMember(SystemMember member) async {
    if (member.hasPin) {
      final unlocked = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UnlockMemberDialog(
          member: member,
          verify: (pin) async {
            final result = await _authentication.authenticate(
              MemberAttribution(member),
              pin,
            );
            return result == AuthenticationResult.granted;
          },
        ),
      );
      return unlocked == true ? member : null;
    }

    final choice = await showDialog<MissingPinChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MissingMemberPinDialog(member: member),
    );
    if (choice == MissingPinChoice.later) return member;
    if (choice != MissingPinChoice.setNow || !mounted) return null;
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SetMemberPinDialog(member: member),
    );
    if (pin == null) return null;
    await _members.setPin(memberId: member.id, pin: pin);
    return SystemMember.fromStorage(
      id: member.id,
      name: member.name,
      hasPin: true,
    );
  }

  Future<void> _activateCurrentMember(SystemMember? member) async {
    _messages.clearSensitiveCache();
    if (member == null) {
      _session.useAnonymous();
    } else {
      _session.activate(member);
    }
    _update(() => _view.currentAuthor = member);
    await _messages.setViewer(member?.id, reloadConversation: !_view.homeMode);
    await _loadWorkspace(selectId: _view.selected?.id);
    if (_view.handoverMode) await _loadHandovers();
    if (_view.taskMode) await _loadTasks();
    if (_view.logMode) await _loadSystemLog();
  }

  Future<void> _loadHome() async {
    _update(() {
      _view.loadingHome = true;
      _view.homeError = null;
    });
    try {
      final summary = await _homeRepository.summary(
        viewerId: _view.currentAuthor?.id,
      );
      _update(() => _view.homeSummary = summary);
    } catch (exception) {
      _update(() => _view.homeError = exception.toString());
    } finally {
      _update(() => _view.loadingHome = false);
    }
  }

  Future<void> _openHandovers() async {
    if (!_ensureConversation()) return;
    _update(() {
      _view.homeMode = false;
      _view.handoverMode = true;
      _view.taskMode = false;
      _view.logMode = false;
    });
    await _loadHandovers();
  }

  Future<void> _openSystemLog() async {
    _update(() {
      _view.homeMode = false;
      _view.logMode = true;
      _view.handoverMode = false;
      _view.taskMode = false;
    });
    await _loadSystemLog();
  }

  Future<void> _openTasks() async {
    if (!_ensureConversation()) return;
    _update(() {
      _view.homeMode = false;
      _view.taskMode = true;
      _view.handoverMode = false;
      _view.logMode = false;
    });
    await _loadTasks();
  }

  Future<void> _manageMembers() async {
    final action = await showDialog<MemberManagementAction>(
      context: context,
      builder: (_) => MemberManagementDialog(members: _view.members),
    );
    if (action == null || !mounted) return;
    if (action.type == MemberManagementActionType.create) {
      await _createMember(addToSelectedConversation: false);
      return;
    }
    final member = action.member!;
    final authorizedMember = await _authorizeMember(member);
    if (authorizedMember == null || !mounted) return;
    if (action.type == MemberManagementActionType.rename) {
      final controller = TextEditingController(text: authorizedMember.name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename member'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.isEmpty || name == authorizedMember.name) return;
      final renamed = await _members.renameMember(
        memberId: authorizedMember.id,
        displayName: name,
      );
      if (_view.currentAuthor?.id == renamed.id) {
        await _activateCurrentMember(renamed);
      } else {
        await _loadWorkspace(selectId: _view.selected?.id);
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${authorizedMember.name}?'),
        content: const Text(
          'The profile will no longer be selectable. Existing messages and history will keep their attribution.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove profile'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _members.archiveMember(authorizedMember.id);
    if (_view.currentAuthor?.id == authorizedMember.id) {
      await _activateCurrentMember(null);
    } else {
      await _loadWorkspace(selectId: _view.selected?.id);
    }
  }

  Future<void> _loadTasks() async {
    if (_view.selected == null) return;
    final tasks = await _taskRepository.list(
      conversationId: _view.selected!.id,
      viewerId: _view.currentAuthor?.id,
    );
    _update(() => _view.tasks = tasks);
  }

  Future<void> _createTask() async {
    if (_view.selected == null) return;
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (_) => CreateTaskDialog(members: _view.selected!.members),
    );
    if (draft == null) return;
    await _taskRepository.create(
      conversationId: _view.selected!.id,
      title: draft.title,
      assignment: draft.assignment,
      assigneeIds: draft.assigneeIds,
      status: draft.status,
      authorId: _view.currentAuthor?.id,
      deadline: draft.deadline,
      reminderAt: draft.reminderAt,
    );
    await _loadTasks();
  }

  Future<void> _updateTaskStatus(WorkspaceTask task, TaskStatus status) async {
    if (task.status == status) return;
    await _taskRepository.updateStatus(
      taskId: task.id,
      status: status,
      actorId: _view.currentAuthor?.id,
    );
    await _loadTasks();
  }

  Future<void> _loadSystemLog() async {
    final events = await _systemLogRepository.list(
      viewerId: _view.currentAuthor?.id,
      includeTechnical: _view.includeTechnicalEvents,
    );
    _update(() => _view.systemEvents = events);
  }

  Future<void> _loadHandovers() async {
    if (_view.selected == null) return;
    final handovers = await _handoverRepository.list(
      conversationId: _view.selected!.id,
      viewerId: _view.currentAuthor?.id,
    );
    _update(() => _view.handovers = handovers);
  }

  Future<void> _createHandover() async {
    if (_view.selected == null) return;
    final draft = await showDialog<HandoverDraft>(
      context: context,
      builder: (_) => CreateHandoverDialog(members: _view.selected!.members),
    );
    if (draft == null) return;
    await _handoverRepository.create(
      conversationId: _view.selected!.id,
      summary: draft.summary,
      recipientIds: draft.recipientIds,
      priority: draft.priority,
      items: draft.items,
      context: draft.context,
      expiresAt: draft.expiresAt,
      authorId: _view.currentAuthor?.id,
    );
    await _loadHandovers();
  }

  Future<void> _markHandoverRead(Handover handover) async {
    if (_view.currentAuthor == null) return;
    await _handoverRepository.markRead(
      handoverId: handover.id,
      memberId: _view.currentAuthor!.id,
    );
    await _loadHandovers();
  }

  Future<void> _editMessage(Message message) async {
    final controller = TextEditingController(text: message.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save revision'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && result != message.text) {
      await _messages.edit(message, result, _view.currentAuthor?.id);
    }
  }

  Future<void> _chooseRecipients() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => TargetRecipientsDialog(
        members: _view.selected!.members,
        selectedIds: _view.recipientIds,
      ),
    );
    if (result != null && mounted) {
      _update(() => _view.recipientIds = result);
    }
  }

  Future<void> _transferMessage(Message message) async {
    final targets = _view.conversations
        .where((conversation) => conversation.id != _view.selected?.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create another conversation before transferring information.',
          ),
        ),
      );
      return;
    }
    final target = await showDialog<Conversation>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Transfer to'),
        children: [
          for (final conversation in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, conversation),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(conversation.title),
                subtitle: Text('${conversation.members.length} members'),
              ),
            ),
        ],
      ),
    );
    if (target == null) return;
    final authorId =
        target.members.any((member) => member.id == _view.currentAuthor?.id)
        ? _view.currentAuthor?.id
        : null;
    await _messages.transfer(
      message: message,
      targetConversationId: target.id,
      authorId: authorId,
    );
    await _loadWorkspace(selectId: _view.selected?.id);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Transferred to ${target.title}')));
    }
  }

  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this message?'),
        content: const Text(
          'It will disappear from the conversation, but its revision history will be retained.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _messages.delete(message, _view.currentAuthor?.id);
    }
  }

  Future<void> _showHistory(Message message) async {
    final revisions = await _messages.history(message);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: revisions.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final revision = revisions[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                revision.isDeletion ? 'Message removed' : revision.content,
              ),
              subtitle: Text(
                'Revision ${revision.revision} · ${revision.recordedById ?? 'Unknown'}',
              ),
            );
          },
        ),
      ),
    );
  }
}

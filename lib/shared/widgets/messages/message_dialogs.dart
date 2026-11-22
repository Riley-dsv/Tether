part of 'message_widgets.dart';

class ConversationInput {
  const ConversationInput(this.title, this.memberIds);
  final String title;
  final Set<String> memberIds;
}

class TargetRecipientsDialog extends StatefulWidget {
  const TargetRecipientsDialog({
    super.key,
    required this.members,
    required this.selectedIds,
  });

  final List<SystemMember> members;
  final Set<String> selectedIds;

  @override
  State<TargetRecipientsDialog> createState() => _TargetRecipientsDialogState();
}

class _TargetRecipientsDialogState extends State<TargetRecipientsDialog> {
  late final Set<String> selected = Set.of(widget.selectedIds);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Who can see this message?'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              onTap: () => setState(selected.clear),
              leading: Icon(
                selected.isEmpty
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected.isEmpty ? AppColors.green : AppColors.muted,
              ),
              title: const Text('Shared'),
              subtitle: const Text('Everyone in this conversation'),
            ),
            const Divider(),
            for (final member in widget.members)
              CheckboxListTile(
                value: selected.contains(member.id),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selected.add(member.id);
                  } else {
                    selected.remove(member.id);
                  }
                }),
                secondary: MemberAvatar(member: member, size: 30),
                title: Text(member.name),
                subtitle: selected.contains(member.id)
                    ? Text(selected.length == 1 ? 'Private' : 'Selected group')
                    : null,
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, Set<String>.of(selected)),
        child: const Text('Apply visibility'),
      ),
    ],
  );
}

class CreateConversationDialog extends StatefulWidget {
  const CreateConversationDialog({super.key, required this.members});
  final List<SystemMember> members;

  @override
  State<CreateConversationDialog> createState() =>
      _CreateConversationDialogState();
}

class _CreateConversationDialogState extends State<CreateConversationDialog> {
  final title = TextEditingController();
  final selectedIds = <String>{};

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New conversation'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Conversation name'),
            ),
            const SizedBox(height: 18),
            const Text(
              'Share with',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Optional. Anonymous conversations are allowed.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            if (widget.members.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No members created yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              for (final member in widget.members)
                CheckboxListTile(
                  value: selectedIds.contains(member.id),
                  onChanged: (value) => setState(
                    () => value == true
                        ? selectedIds.add(member.id)
                        : selectedIds.remove(member.id),
                  ),
                  title: Text(member.name),
                  secondary: MemberAvatar(member: member, size: 30),
                  contentPadding: EdgeInsets.zero,
                ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: title.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                ConversationInput(title.text.trim(), Set.of(selectedIds)),
              ),
        child: const Text('Create'),
      ),
    ],
  );
}

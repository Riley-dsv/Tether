part of 'handover_widgets.dart';

/// Validated, non-persisted values returned by [CreateHandoverDialog].
class HandoverDraft {
  /// Creates a handover draft.
  const HandoverDraft({
    required this.summary,
    required this.recipientIds,
    required this.priority,
    required this.items,
    required this.context,
    required this.expiresAt,
  });

  final String summary;
  final Set<String> recipientIds;
  final HandoverPriority priority;
  final List<HandoverItem> items;
  final String? context;
  final DateTime? expiresAt;
}

/// Dialog for composing a structured handover and explicit audience.
class CreateHandoverDialog extends StatefulWidget {
  /// Creates a handover dialog limited to eligible [members].
  const CreateHandoverDialog({super.key, required this.members});
  final List<SystemMember> members;

  @override
  State<CreateHandoverDialog> createState() => _CreateHandoverDialogState();
}

class _CreateHandoverDialogState extends State<CreateHandoverDialog> {
  final summary = TextEditingController();
  final contextController = TextEditingController();
  final completed = TextEditingController();
  final pending = TextEditingController();
  final recipients = <String>{};
  HandoverPriority priority = HandoverPriority.normal;
  DateTime? expiresAt;

  @override
  void dispose() {
    summary.dispose();
    contextController.dispose();
    completed.dispose();
    pending.dispose();
    super.dispose();
  }

  List<HandoverItem> _items(String value, bool isCompleted) => value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => HandoverItem(description: line, isCompleted: isCompleted))
      .toList();

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New handover'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: summary,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Summary'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<HandoverPriority>(
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: [
                for (final value in HandoverPriority.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.name.toUpperCase()),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => priority = value ?? priority),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: completed,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tasks completed',
                hintText: 'One item per line',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pending,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Tasks to be done',
                hintText: 'One item per line',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contextController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Context (optional)',
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Recipients',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final member in widget.members)
              CheckboxListTile(
                value: recipients.contains(member.id),
                onChanged: (value) => setState(
                  () => value == true
                      ? recipients.add(member.id)
                      : recipients.remove(member.id),
                ),
                secondary: MemberAvatar(member: member, size: 30),
                title: Text(member.name),
                contentPadding: EdgeInsets.zero,
              ),
            TextButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  initialDate:
                      expiresAt ?? DateTime.now().add(const Duration(days: 1)),
                );
                if (date != null) setState(() => expiresAt = date);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(
                expiresAt == null
                    ? 'Add expiration'
                    : 'Expires ${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}',
              ),
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
        onPressed: summary.text.trim().isEmpty || recipients.isEmpty
            ? null
            : () => Navigator.pop(
                context,
                HandoverDraft(
                  summary: summary.text.trim(),
                  recipientIds: Set.of(recipients),
                  priority: priority,
                  items: [
                    ..._items(completed.text, true),
                    ..._items(pending.text, false),
                  ],
                  context: contextController.text.trim().isEmpty
                      ? null
                      : contextController.text.trim(),
                  expiresAt: expiresAt,
                ),
              ),
        child: const Text('Create handover'),
      ),
    ],
  );
}

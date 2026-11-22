part of 'task_widgets.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.assignment,
    required this.assigneeIds,
    required this.status,
    this.deadline,
    this.reminderAt,
  });
  final String title;
  final TaskAssignment assignment;
  final Set<String> assigneeIds;
  final TaskStatus status;
  final DateTime? deadline;
  final DateTime? reminderAt;
}

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({super.key, required this.members});
  final List<SystemMember> members;
  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _title = TextEditingController();
  TaskAssignment _assignment = TaskAssignment.anyone;
  final Set<String> _assignees = {};
  TaskStatus _status = TaskStatus.todo;
  DateTime? _deadline;
  bool _remind = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create task'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Task',
                hintText: 'File the tax return',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Who can do it?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            RadioGroup<TaskAssignment>(
              groupValue: _assignment,
              onChanged: (value) => setState(() => _assignment = value!),
              child: const Column(
                children: [
                  RadioListTile(
                    value: TaskAssignment.anyone,
                    title: Text('Anyone can do it'),
                    subtitle: Text('No rigid assignment'),
                  ),
                  RadioListTile(
                    value: TaskAssignment.specific,
                    title: Text('Specific people'),
                  ),
                ],
              ),
            ),
            if (_assignment == TaskAssignment.specific)
              ...widget.members.map(
                (member) => CheckboxListTile(
                  value: _assignees.contains(member.id),
                  title: Text(member.name),
                  secondary: MemberAvatar(member: member, size: 30),
                  onChanged: (checked) => setState(
                    () => checked == true
                        ? _assignees.add(member.id)
                        : _assignees.remove(member.id),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: TaskStatus.todo, child: Text('To do')),
                DropdownMenuItem(
                  value: TaskStatus.inProgress,
                  child: Text('In progress'),
                ),
                DropdownMenuItem(value: TaskStatus.done, child: Text('Done')),
              ],
              onChanged: (value) => setState(() => _status = value!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                _deadline == null
                    ? 'Add deadline'
                    : 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
              ),
              onTap: _chooseDeadline,
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _deadline = null;
                        _remind = false;
                      }),
                    ),
            ),
            if (_deadline != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _remind,
                title: const Text('Remind on deadline day'),
                onChanged: (value) => setState(() => _remind = value),
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
        onPressed: _canSubmit ? _submit : null,
        child: const Text('Create'),
      ),
    ],
  );

  bool get _canSubmit =>
      _title.text.trim().isNotEmpty &&
      (_assignment == TaskAssignment.anyone || _assignees.isNotEmpty);
  Future<void> _chooseDeadline() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _deadline ?? DateTime.now(),
    );
    if (date != null) setState(() => _deadline = date);
  }

  void _submit() {
    final deadline = _deadline == null
        ? null
        : DateTime(_deadline!.year, _deadline!.month, _deadline!.day, 23, 59);
    Navigator.pop(
      context,
      TaskDraft(
        title: _title.text.trim(),
        assignment: _assignment,
        assigneeIds: {..._assignees},
        status: _status,
        deadline: deadline,
        reminderAt: _remind && _deadline != null
            ? DateTime(_deadline!.year, _deadline!.month, _deadline!.day, 9)
            : null,
      ),
    );
  }
}

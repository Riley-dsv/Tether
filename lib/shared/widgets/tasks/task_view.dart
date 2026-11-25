part of 'task_widgets.dart';

/// Task list surface for one selected conversation.
class TaskView extends StatelessWidget {
  /// Creates a task view with externally owned mutations.
  const TaskView({
    super.key,
    required this.tasks,
    required this.onCreate,
    required this.onStatusChanged,
    required this.onBack,
  });
  final List<WorkspaceTask> tasks;
  final VoidCallback onCreate;
  final void Function(WorkspaceTask, TaskStatus) onStatusChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFBFAF6),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
              const Expanded(
                child: Text(
                  'Tasks & reminders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
            ],
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text(
                    'No tasks yet',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _TaskCard(
                    task: tasks[index],
                    onStatusChanged: onStatusChanged,
                  ),
                ),
        ),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onStatusChanged});
  final WorkspaceTask task;
  final void Function(WorkspaceTask, TaskStatus) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.done;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: done,
              onChanged: (value) => onStatusChanged(
                task,
                value == true ? TaskStatus.done : TaskStatus.todo,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _TaskTag(
                        icon: switch (task.status) {
                          TaskStatus.todo => Icons.radio_button_unchecked,
                          TaskStatus.inProgress => Icons.timelapse,
                          TaskStatus.done => Icons.check_circle_outline,
                        },
                        label: switch (task.status) {
                          TaskStatus.todo => 'To do',
                          TaskStatus.inProgress => 'In progress',
                          TaskStatus.done => 'Done',
                        },
                      ),
                      _TaskTag(
                        icon: task.assignment == TaskAssignment.anyone
                            ? Icons.groups_outlined
                            : Icons.person_outline,
                        label: task.assignment == TaskAssignment.anyone
                            ? 'Anyone can do it'
                            : task.assignees
                                  .map((member) => member.name)
                                  .join(', '),
                      ),
                      if (task.deadline != null)
                        _TaskTag(
                          icon: Icons.event_outlined,
                          label:
                              '${task.deadline!.toLocal().day}/${task.deadline!.toLocal().month}/${task.deadline!.toLocal().year}',
                        ),
                      if (task.reminderAt != null)
                        const _TaskTag(
                          icon: Icons.notifications_none,
                          label: 'Reminder set',
                        ),
                    ],
                  ),
                  if (task.assignment == TaskAssignment.specific &&
                      task.assignees.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          for (final member in task.assignees.take(4))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: MemberAvatar(member: member, size: 25),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<TaskStatus>(
              initialValue: task.status,
              onSelected: (status) => onStatusChanged(task, status),
              itemBuilder: (_) => TaskStatus.values
                  .map(
                    (status) => PopupMenuItem(
                      value: status,
                      child: Text(switch (status) {
                        TaskStatus.todo => 'To do',
                        TaskStatus.inProgress => 'In progress',
                        TaskStatus.done => 'Done',
                      }),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTag extends StatelessWidget {
  const _TaskTag({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.sage.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

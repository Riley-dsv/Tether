part of 'message_widgets.dart';

/// Empty-state actions for creating the first member or conversation.
class EmptyWorkspace extends StatelessWidget {
  /// Creates the workspace onboarding surface.
  const EmptyWorkspace({
    super.key,
    required this.hasMembers,
    required this.onCreateMember,
    required this.onCreateConversation,
  });

  final bool hasMembers;
  final VoidCallback onCreateMember;
  final VoidCallback onCreateConversation;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.all_inclusive_rounded,
              size: 48,
              color: AppColors.green,
            ),
            const SizedBox(height: 18),
            Text(
              hasMembers
                  ? 'Create your first conversation'
                  : 'Start your local workspace',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              hasMembers
                  ? 'Choose who can participate. Every selected member has equal permissions.'
                  : 'Create a member identity, or begin with an anonymous conversation. Nothing is predefined.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onCreateMember,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Create member'),
                ),
                FilledButton.icon(
                  onPressed: onCreateConversation,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Create conversation'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dialog that validates and returns a new member display name.
class CreateMemberDialog extends StatefulWidget {
  /// Creates the member dialog.
  const CreateMemberDialog({super.key});

  @override
  State<CreateMemberDialog> createState() => _CreateMemberDialogState();
}

class _CreateMemberDialogState extends State<CreateMemberDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create member'),
    content: TextField(
      controller: controller,
      autofocus: true,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Display name',
        hintText: 'Choose any name',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: controller.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Create'),
      ),
    ],
  );
}

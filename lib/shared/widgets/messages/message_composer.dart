part of 'message_widgets.dart';

/// Message entry surface with optional author and targeted recipients.
///
/// Selecting no author preserves unknown attribution; it does not create or
/// select a synthetic member.
class MessageComposer extends StatelessWidget {
  /// Creates a controlled composer.
  const MessageComposer({
    super.key,
    required this.controller,
    required this.author,
    required this.members,
    required this.recipientIds,
    required this.onChooseRecipients,
    required this.onCreateMember,
    required this.onAuthorChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final SystemMember? author;
  final List<SystemMember> members;
  final Set<String> recipientIds;
  final VoidCallback onChooseRecipients;
  final VoidCallback onCreateMember;
  final ValueChanged<SystemMember?> onAuthorChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Container(
      padding: EdgeInsets.fromLTRB(
        mobile ? 12 : 24,
        10,
        mobile ? 12 : 24,
        mobile ? 12 : 18,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFBFAF6),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Writing as',
                style: TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(width: 7),
              InkWell(
                key: const Key('message-author-selector'),
                onTap: () => _chooseAuthor(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MemberAvatar(member: author, size: 22),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: mobile ? 80 : 140,
                        ),
                        child: Text(
                          key: const Key('message-current-author'),
                          author?.name ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.swap_horiz_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              if (members.isEmpty)
                TextButton.icon(
                  onPressed: onCreateMember,
                  icon: const Icon(Icons.person_add_outlined, size: 15),
                  label: const Text('Create member'),
                ),
              if (members.isNotEmpty)
                TextButton.icon(
                  onPressed: onChooseRecipients,
                  icon: Icon(
                    recipientIds.isEmpty
                        ? Icons.public
                        : recipientIds.length == 1
                        ? Icons.lock_outline
                        : Icons.group_outlined,
                    size: 15,
                  ),
                  label: Text(
                    recipientIds.isEmpty
                        ? 'Shared'
                        : recipientIds.length == 1
                        ? 'Private'
                        : 'Group (${recipientIds.length})',
                  ),
                ),
              if (!mobile) ...[
                const Text(
                  'Visible to conversation members',
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 3,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Write a message…',
              suffixIcon: Padding(
                padding: const EdgeInsets.all(5),
                child: IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.green),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseAuthor(BuildContext context) async {
    final choice = await showDialog<_AuthorChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Who is writing?'),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        content: SizedBox(
          width: 380,
          height: (members.length * 64 + 120).clamp(220, 420).toDouble(),
          child: ListView(
            children: [
              for (final member in members)
                ListTile(
                  key: Key('message-author-${member.id}'),
                  leading: MemberAvatar(member: member, size: 32),
                  title: Text(member.name),
                  trailing: author?.id == member.id
                      ? const Icon(Icons.check, color: AppColors.green)
                      : null,
                  onTap: () => Navigator.pop(context, _AuthorChoice(member)),
                ),
              ListTile(
                key: const Key('message-author-unknown'),
                leading: const MemberAvatar(member: null, size: 32),
                title: const Text('Unknown / not specified'),
                subtitle: const Text(
                  'Post without assigning a specific member',
                ),
                trailing: author == null
                    ? const Icon(Icons.check, color: AppColors.green)
                    : null,
                onTap: () => Navigator.pop(context, const _AuthorChoice(null)),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) onAuthorChanged(choice.member);
  }
}

class _AuthorChoice {
  const _AuthorChoice(this.member);
  final SystemMember? member;
}

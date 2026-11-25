part of 'message_widgets.dart';

/// Desktop side panel summarizing a conversation's sharing boundary.
class SharedContextPanel extends StatelessWidget {
  /// Creates a context panel for [conversation].
  const SharedContextPanel({super.key, required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(left: BorderSide(color: AppColors.line)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shared context',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        Text(
          'MEMBERS · ${conversation.members.length}',
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (conversation.members.isEmpty)
          const Text(
            'No members assigned',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          )
        else
          for (final member in conversation.members) _MemberRow(member: member),
      ],
    ),
  );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});
  final SystemMember member;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        MemberAvatar(member: member, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            member.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

part of 'message_widgets.dart';

/// Presents one decrypted message revision and its available actions.
class MessageCard extends StatelessWidget {
  /// Creates a message card for the current viewer context.
  const MessageCard({
    super.key,
    required this.message,
    required this.onPin,
    required this.onSeen,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
    required this.onTransfer,
    required this.currentMemberId,
  });

  final Message message;
  final VoidCallback onPin;
  final VoidCallback? onSeen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHistory;
  final VoidCallback onTransfer;
  final String? currentMemberId;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MemberAvatar(member: message.author, size: 34),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  message.author?.name ?? 'Unknown sender',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message.time,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
                if (message.isPinned)
                  const Text(
                    'Pinned',
                    style: TextStyle(color: Color(0xFFA67527), fontSize: 10),
                  ),
                if (message.isEdited)
                  const Text(
                    'Edited',
                    style: TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                _VisibilityBadge(message: message),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
              decoration: BoxDecoration(
                color: message.isPinned
                    ? AppColors.amber.withValues(alpha: .3)
                    : Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: message.isPinned ? AppColors.amber : AppColors.line,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.sourceMessageId != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.move_to_inbox_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Transferred from ${message.sourceConversationTitle ?? 'another space'}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                  ],
                  Text(
                    message.text,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: onPin,
                        icon: Icon(
                          message.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 14,
                        ),
                        label: Text(message.isPinned ? 'Unpin' : 'Pin'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.muted,
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: message.seenBy.contains(currentMemberId)
                            ? null
                            : onSeen,
                        icon: Icon(
                          message.seenBy.contains(currentMemberId)
                              ? Icons.done_all
                              : Icons.done,
                          size: 15,
                        ),
                        label: Tooltip(
                          message: message.seenByNames.isEmpty
                              ? 'No members have marked this as seen'
                              : 'Seen by ${message.seenByNames.join(', ')}',
                          child: Text(
                            message.seenBy.isEmpty
                                ? 'Mark seen'
                                : 'Seen by ${message.seenBy.length}',
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.green,
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') onEdit();
                          if (action == 'history') onHistory();
                          if (action == 'transfer') onTransfer();
                          if (action == 'delete') onDelete();
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                            value: 'transfer',
                            child: Text('Transfer to another space'),
                          ),
                          PopupMenuItem(
                            value: 'history',
                            child: Text('Revision history'),
                          ),
                          PopupMenuItem(value: 'delete', child: Text('Remove')),
                        ],
                        icon: const Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (message.visibility) {
      MessageVisibility.private => (
        Icons.lock_outline,
        message.recipientNames.isEmpty
            ? 'Private'
            : 'Private · ${message.recipientNames.first}',
        const Color(0xFF76558E),
      ),
      MessageVisibility.group => (
        Icons.group_outlined,
        'Group · ${message.recipientNames.join(', ')}',
        const Color(0xFF486B83),
      ),
      MessageVisibility.shared => (Icons.public, 'Shared', AppColors.green),
    };
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

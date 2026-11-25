part of 'message_widgets.dart';

/// Adaptive list of the general space and persistent group conversations.
class ConversationList extends StatefulWidget {
  /// Creates a selectable conversation list.
  const ConversationList({
    super.key,
    required this.conversations,
    required this.selectedId,
    required this.unreadCount,
    required this.onSelected,
    required this.onAdd,
    this.mobile = false,
  });

  final List<Conversation> conversations;
  final String? selectedId;
  final int unreadCount;
  final ValueChanged<Conversation> onSelected;
  final VoidCallback onAdd;
  final bool mobile;

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.conversations
        .where(
          (conversation) =>
              conversation.title.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final general = visible.where((conversation) => conversation.isGeneral);
    final groups = visible.where((conversation) => !conversation.isGeneral);
    return SizedBox(
      width: widget.mobile ? double.infinity : 280,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(right: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 14, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                onChanged: (value) => setState(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Find a conversation',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No conversations',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    if (general.isNotEmpty) ...[
                      const _ConversationSectionLabel('GENERAL'),
                      for (final conversation in general)
                        _ConversationTile(
                          conversation: conversation,
                          selected: conversation.id == widget.selectedId,
                          unreadCount: conversation.id == widget.selectedId
                              ? widget.unreadCount
                              : conversation.unreadCount,
                          onTap: () => widget.onSelected(conversation),
                        ),
                    ],
                    if (groups.isNotEmpty) ...[
                      const _ConversationSectionLabel('GROUPS'),
                      for (final conversation in groups)
                        _ConversationTile(
                          conversation: conversation,
                          selected: conversation.id == widget.selectedId,
                          unreadCount: conversation.id == widget.selectedId
                              ? widget.unreadCount
                              : conversation.unreadCount,
                          onTap: () => widget.onSelected(conversation),
                        ),
                    ],
                  ],
                ),
              ),
            if (visible.isEmpty) const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AppColors.green,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Stored locally',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSectionLabel extends StatelessWidget {
  const _ConversationSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 5),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.unreadCount,
    required this.onTap,
  });

  final Conversation conversation;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : null,
          borderRadius: BorderRadius.circular(13),
          border: selected ? Border.all(color: AppColors.line) : null,
        ),
        child: Row(
          children: [
            _ConversationAvatar(
              members: conversation.members,
              isGeneral: conversation.isGeneral,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage ?? _spaceVisibility(conversation),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.members, required this.isGeneral});
  final List<SystemMember> members;
  final bool isGeneral;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 42,
    height: 42,
    child: isGeneral
        ? Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.public, color: AppColors.green, size: 20),
          )
        : Stack(
            children: [
              MemberAvatar(
                member: members.isEmpty ? null : members.first,
                size: 34,
              ),
              if (members.length > 1)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: MemberAvatar(
                    member: members[1],
                    size: 25,
                    border: true,
                  ),
                ),
            ],
          ),
  );
}

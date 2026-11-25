part of 'message_widgets.dart';

/// Conversation title bar with an optional controlled search field.
class ConversationHeader extends StatelessWidget {
  /// Creates a header for [conversation].
  const ConversationHeader({
    super.key,
    required this.conversation,
    required this.showSearch,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggleSearch,
  });

  final Conversation conversation;
  final bool showSearch;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final names = conversation.members.map((member) => member.name).join(', ');
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  names.isEmpty
                      ? 'Shared space · anonymous posting allowed'
                      : '${_spaceVisibility(conversation)} · $names',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (showSearch)
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search messages',
                    isDense: true,
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: onToggleSearch,
            icon: Icon(showSearch ? Icons.close : Icons.search),
          ),
        ],
      ),
    );
  }
}

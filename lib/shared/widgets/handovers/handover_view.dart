part of 'handover_widgets.dart';

/// Handover list surface scoped to one conversation and viewer.
class HandoverView extends StatelessWidget {
  /// Creates a handover view with externally owned mutations.
  const HandoverView({
    super.key,
    required this.handovers,
    required this.currentMemberId,
    required this.onCreate,
    required this.onMarkRead,
    required this.onBack,
  });

  final List<Handover> handovers;
  final String? currentMemberId;
  final VoidCallback onCreate;
  final ValueChanged<Handover> onMarkRead;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFBFAF6),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to messages',
              ),
              const Expanded(
                child: Text(
                  'Handovers',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('New handover'),
              ),
            ],
          ),
        ),
        Expanded(
          child: handovers.isEmpty
              ? const Center(
                  child: Text(
                    'No handovers for this identity',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: handovers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final handover = handovers[index];
                    final isRead =
                        currentMemberId != null &&
                        handover.readBy.contains(currentMemberId);
                    return _HandoverCard(
                      handover: handover,
                      isRead: isRead,
                      canMarkRead: currentMemberId != null && !isRead,
                      onMarkRead: () => onMarkRead(handover),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _HandoverCard extends StatelessWidget {
  const _HandoverCard({
    required this.handover,
    required this.isRead,
    required this.canMarkRead,
    required this.onMarkRead,
  });

  final Handover handover;
  final bool isRead;
  final bool canMarkRead;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (handover.priority) {
      HandoverPriority.urgent => const Color(0xFFB43E37),
      HandoverPriority.high => const Color(0xFFB06D25),
      HandoverPriority.normal => AppColors.green,
      HandoverPriority.low => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: handover.isExpired ? const Color(0xFFD59B96) : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 5,
                height: 34,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  handover.summary,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                handover.priority.name.toUpperCase(),
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (final recipient in handover.recipients)
                Chip(
                  avatar: MemberAvatar(member: recipient, size: 20),
                  label: Text(recipient.name),
                  visualDensity: VisualDensity.compact,
                ),
              if (handover.isExpired)
                const Chip(
                  label: Text('Expired'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (handover.context != null) ...[
            const SizedBox(height: 8),
            Text(
              handover.context!,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
          if (handover.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final item in handover.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.isCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: item.isCompleted
                          ? AppColors.green
                          : AppColors.muted,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Divider(height: 22),
          Row(
            children: [
              const Icon(Icons.done_all, size: 15, color: AppColors.muted),
              const SizedBox(width: 5),
              Text(
                'Read by ${handover.readBy.length}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
              if (handover.expiresAt != null)
                Text(
                  'Expires ${handover.expiresAt!.toLocal().day}/${handover.expiresAt!.toLocal().month}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              if (canMarkRead)
                TextButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.done, size: 16),
                  label: const Text('Mark read'),
                ),
              if (isRead)
                const Text(
                  'Read',
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

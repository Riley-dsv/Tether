part of 'message_widgets.dart';

/// Desktop navigation rail for the workspace's feature modes.
class WorkspaceNavigation extends StatelessWidget {
  /// Creates navigation with externally owned selection state.
  const WorkspaceNavigation({
    super.key,
    required this.currentMember,
    required this.homeSelected,
    required this.onHome,
    required this.onMessages,
    required this.pinnedOnly,
    required this.onPinnedToggle,
    required this.handoversSelected,
    required this.onHandovers,
    required this.tasksSelected,
    required this.onTasks,
    required this.logSelected,
    required this.onSystemLog,
  });

  final SystemMember? currentMember;
  final bool homeSelected;
  final VoidCallback onHome;
  final VoidCallback? onMessages;
  final bool pinnedOnly;
  final VoidCallback? onPinnedToggle;
  final bool handoversSelected;
  final VoidCallback? onHandovers;
  final bool tasksSelected;
  final VoidCallback? onTasks;
  final bool logSelected;
  final VoidCallback onSystemLog;

  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    color: AppColors.ink,
    child: Column(
      children: [
        const SizedBox(height: 18),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.sage,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.all_inclusive_rounded,
            color: AppColors.green,
          ),
        ),
        const SizedBox(height: 26),
        _RailButton(
          icon: Icons.home_outlined,
          selected: homeSelected,
          onTap: onHome,
        ),
        _RailButton(
          icon: Icons.forum_outlined,
          selected:
              !homeSelected &&
              !pinnedOnly &&
              !handoversSelected &&
              !tasksSelected &&
              !logSelected,
          onTap: onMessages,
        ),
        _RailButton(
          icon: Icons.push_pin_outlined,
          selected: pinnedOnly,
          onTap: onPinnedToggle,
        ),
        _RailButton(
          icon: Icons.move_to_inbox_outlined,
          selected: handoversSelected,
          onTap: onHandovers,
        ),
        _RailButton(
          icon: Icons.task_alt_outlined,
          selected: tasksSelected,
          onTap: onTasks,
        ),
        _RailButton(
          icon: Icons.history_rounded,
          selected: logSelected,
          onTap: onSystemLog,
        ),
        const Spacer(),
        const _RailButton(icon: Icons.lock_outline_rounded),
        Padding(
          padding: const EdgeInsets.only(bottom: 18, top: 8),
          child: MemberAvatar(member: currentMember, size: 36),
        ),
      ],
    ),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.icon, this.selected = false, this.onTap});
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: .12) : null,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : const Color(0xFFAEB3AA),
          size: 20,
        ),
      ),
    ),
  );
}

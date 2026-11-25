import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/features/home/home_summary.dart';
import 'package:note_app/shared/models/system_member.dart';
import 'package:note_app/shared/widgets/member_avatar.dart';

/// Scrollable dashboard answering what the current viewer needs to know now.
///
/// Unknown viewers receive the shared, privacy-safe summary rather than being
/// forced to select or create an identity.
class HomeView extends StatelessWidget {
  /// Creates the dashboard projection and its navigation callbacks.
  const HomeView({
    super.key,
    required this.summary,
    required this.members,
    required this.currentMember,
    required this.loading,
    required this.error,
    required this.onMemberChanged,
    required this.onMessages,
    required this.onHandovers,
    required this.onTasks,
    required this.onCreateMember,
    required this.onCreateConversation,
    required this.onManageMembers,
  });

  final HomeSummary summary;
  final List<SystemMember> members;
  final SystemMember? currentMember;
  final bool loading;
  final String? error;
  final ValueChanged<SystemMember?> onMemberChanged;
  final VoidCallback? onMessages;
  final VoidCallback? onHandovers;
  final VoidCallback? onTasks;
  final VoidCallback onCreateMember;
  final VoidCallback onCreateConversation;
  final VoidCallback onManageMembers;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFFBFAF6),
    child: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What do I need to know right now?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentMember == null
                          ? 'A shared overview without assigning an identity.'
                          : 'A focused summary for ${currentMember!.name}.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_IdentityChoice>(
                tooltip: 'Choose current member',
                onSelected: (choice) => onMemberChanged(choice.member),
                itemBuilder: (_) => [
                  const PopupMenuItem<_IdentityChoice>(
                    value: _IdentityChoice(null),
                    child: Text('Unknown'),
                  ),
                  ...members.map(
                    (member) => PopupMenuItem<_IdentityChoice>(
                      value: _IdentityChoice(member),
                      child: Text(member.name),
                    ),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MemberAvatar(member: currentMember, size: 36),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Manage members',
                onPressed: onManageMembers,
                icon: const Icon(Icons.manage_accounts_outlined),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            _HomeError(message: error!)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 760
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _SummaryCard(
                      width: width,
                      icon: Icons.mark_email_unread_outlined,
                      value: '${summary.unreadMessages}',
                      label: summary.unreadMessages == 1
                          ? 'unread message'
                          : 'unread messages',
                      onTap: onMessages,
                    ),
                    _SummaryCard(
                      width: width,
                      icon: Icons.priority_high_rounded,
                      value: '${summary.importantHandovers}',
                      label: summary.importantHandovers == 1
                          ? 'important handover'
                          : 'important handovers',
                      onTap: onHandovers,
                    ),
                    _SummaryCard(
                      width: width,
                      icon: Icons.today_outlined,
                      value: '${summary.tasksToday}',
                      label: summary.tasksToday == 1
                          ? 'task for today'
                          : 'tasks for today',
                      onTap: onTasks,
                    ),
                    _NextCard(
                      width: width,
                      item: summary.nextItem,
                      onTap: onTasks,
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onMessages,
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Open shared conversation'),
              ),
              OutlinedButton.icon(
                onPressed: onCreateConversation,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New conversation'),
              ),
              if (members.isEmpty)
                OutlinedButton.icon(
                  onPressed: onCreateMember,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Create member'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _IdentityChoice {
  const _IdentityChoice(this.member);
  final SystemMember? member;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });
  final double width;
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 28, color: AppColors.green),
              const SizedBox(width: 16),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.width, required this.item, this.onTap});
  final double width;
  final HomeNextItem? item;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final local = item?.at.toLocal();
    final time = local == null
        ? '—'
        : '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final kind = item?.kind == HomeNextItemKind.reminder
        ? 'Next reminder'
        : 'Next deadline';
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: item == null ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 28, color: AppColors.green),
                const SizedBox(width: 16),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item == null
                        ? 'No upcoming reminder or deadline'
                        : '$kind\n${item!.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        const Icon(Icons.error_outline, size: 44, color: AppColors.muted),
        const SizedBox(height: 12),
        const Text(
          'The dashboard could not be loaded.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(message, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );
}

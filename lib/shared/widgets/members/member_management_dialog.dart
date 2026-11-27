import 'package:material_ui/material_ui.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/shared/widgets/members/member_avatar.dart';

/// Actions returned by [MemberManagementDialog].
enum MemberManagementActionType { create, rename, remove }

/// Typed result from member management.
class MemberManagementAction {
  /// Creates an add-member action with no existing member target.
  const MemberManagementAction.create()
    : member = null,
      type = MemberManagementActionType.create;

  /// Creates an action targeting [member].
  const MemberManagementAction({required this.member, required this.type});

  /// Existing member affected by rename/remove, otherwise `null`.
  final SystemMember? member;

  /// Requested operation.
  final MemberManagementActionType type;
}

/// Dialog for adding, renaming, or archiving internal member profiles.
class MemberManagementDialog extends StatelessWidget {
  /// Creates a management dialog for active [members].
  const MemberManagementDialog({super.key, required this.members});
  final List<SystemMember> members;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Manage members'),
    content: SizedBox(
      width: 420,
      child: members.isEmpty
          ? const Text('No member profiles')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  leading: MemberAvatar(member: member, size: 34),
                  title: Text(member.name),
                  trailing: PopupMenuButton<MemberManagementActionType>(
                    onSelected: (type) => Navigator.pop(
                      context,
                      MemberManagementAction(member: member, type: type),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: MemberManagementActionType.rename,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Rename'),
                        ),
                      ),
                      PopupMenuItem(
                        value: MemberManagementActionType.remove,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.person_remove_outlined),
                          title: Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    ),
    actions: [
      FilledButton.icon(
        onPressed: () =>
            Navigator.pop(context, const MemberManagementAction.create()),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add member'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

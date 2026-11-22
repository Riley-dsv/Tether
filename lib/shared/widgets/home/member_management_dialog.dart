import 'package:material_ui/material_ui.dart';
import 'package:note_app/shared/models/system_member.dart';
import 'package:note_app/shared/widgets/member_avatar.dart';

enum MemberManagementActionType { rename, remove }

class MemberManagementAction {
  const MemberManagementAction({required this.member, required this.type});
  final SystemMember member;
  final MemberManagementActionType type;
}

class MemberManagementDialog extends StatelessWidget {
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
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

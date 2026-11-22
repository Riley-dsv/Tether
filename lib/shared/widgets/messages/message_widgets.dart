import 'package:material_ui/material_ui.dart';
import 'package:note_app/app/app_theme.dart';
import 'package:note_app/features/groups/conversation.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/shared/models/system_member.dart';
import 'package:note_app/shared/widgets/member_avatar.dart';

part 'workspace_navigation.dart';
part 'conversation_list.dart';
part 'conversation_header.dart';
part 'message_card.dart';
part 'message_composer.dart';
part 'shared_context_panel.dart';
part 'empty_workspace.dart';
part 'message_dialogs.dart';

String _spaceVisibility(Conversation conversation) => conversation.isGeneral
    ? 'Everyone'
    : conversation.members.isEmpty
    ? 'Shared space'
    : conversation.members.length == 1
    ? 'Private space'
    : 'Group space';

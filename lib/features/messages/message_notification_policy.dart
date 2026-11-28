import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/members/member_session.dart';

/// Produces notification text without exposing unauthorized message content.
abstract final class MessageNotificationPolicy {
  static String preview(Message message, {String? viewerId}) {
    final visible =
        message.visibility == MessageVisibility.shared ||
        (viewerId != null &&
            (message.author?.id == viewerId ||
                message.recipientIds.contains(viewerId)));
    return visible ? message.text : 'New protected message';
  }
}

/// Notification projection whose viewer comes only from the active session.
class SessionBoundNotificationPolicy {
  const SessionBoundNotificationPolicy(this._session);

  final MemberSession _session;

  String preview(Message message) =>
      MessageNotificationPolicy.preview(message, viewerId: _session.memberId);
}

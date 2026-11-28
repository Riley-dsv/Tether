import 'package:note_app/features/messages/message.dart';

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

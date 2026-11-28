import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/home/home_summary.dart';
import 'package:note_app/features/members/member_session.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/system_log/system_event.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';

/// Application-layer gate binding viewer IDs to the active member session.
class SessionBoundMessageStore implements MessageStore {
  SessionBoundMessageStore(this._delegate, this._session);

  final MessageStore _delegate;
  final MemberSession _session;

  String? _readViewer(String? requested) =>
      requested != null && _session.permitsMember(requested) ? requested : null;

  void _requireActor(String? actorId) {
    if (actorId != null && !_session.permitsMember(actorId)) {
      throw StateError('Member is not authenticated in the active session');
    }
  }

  @override
  Future<void> prepare() => _delegate.prepare();

  @override
  Future<List<Message>> watchSnapshot({
    required String conversationId,
    String query = '',
    bool pinnedOnly = false,
    String? viewerId,
    MessageCursor? before,
    int? limit,
  }) => _delegate.watchSnapshot(
    conversationId: conversationId,
    query: query,
    pinnedOnly: pinnedOnly,
    viewerId: _readViewer(viewerId),
    before: before,
    limit: limit,
  );

  @override
  Future<Message> create({
    required String conversationId,
    required String content,
    String? authorId,
    Set<String> recipientIds = const {},
    String? sourceMessageId,
  }) {
    _requireActor(authorId);
    return _delegate.create(
      conversationId: conversationId,
      content: content,
      authorId: authorId,
      recipientIds: recipientIds,
      sourceMessageId: sourceMessageId,
    );
  }

  @override
  Future<void> edit({
    required String messageId,
    required String content,
    String? editedById,
  }) {
    _requireActor(editedById);
    return _delegate.edit(
      messageId: messageId,
      content: content,
      editedById: editedById,
    );
  }

  @override
  Future<void> delete({required String messageId, String? deletedById}) {
    _requireActor(deletedById);
    return _delegate.delete(messageId: messageId, deletedById: deletedById);
  }

  @override
  Future<void> setPinned({
    required String messageId,
    required bool pinned,
    String? actorId,
  }) {
    _requireActor(actorId);
    return _delegate.setPinned(
      messageId: messageId,
      pinned: pinned,
      actorId: actorId,
    );
  }

  @override
  Future<void> markSeen({required String messageId, required String memberId}) {
    _requireActor(memberId);
    return _delegate.markSeen(messageId: messageId, memberId: memberId);
  }

  @override
  Future<int> unreadCount({
    required String conversationId,
    required String memberId,
  }) {
    _requireActor(memberId);
    return _delegate.unreadCount(
      conversationId: conversationId,
      memberId: memberId,
    );
  }

  @override
  Future<List<MessageRevision>> history(String messageId, {String? viewerId}) =>
      _delegate.history(messageId, viewerId: _readViewer(viewerId));
}

/// Fail-closed home projection bound to the active member session.
class SessionBoundHomeStore implements HomeStore {
  SessionBoundHomeStore(this._delegate, this._session);

  final HomeStore _delegate;
  final MemberSession _session;

  @override
  Future<HomeSummary> summary({required String? viewerId}) {
    if (viewerId == null || !_session.permitsMember(viewerId)) {
      return Future.value(const HomeSummary.empty());
    }
    return _delegate.summary(viewerId: viewerId);
  }
}

/// Fail-closed activity feed bound to the active member session.
class SessionBoundSystemLogStore implements SystemLogStore {
  SessionBoundSystemLogStore(this._delegate, this._session);

  final SystemLogStore _delegate;
  final MemberSession _session;

  @override
  Future<List<SystemEvent>> list({
    String? viewerId,
    bool includeTechnical = false,
    int limit = 250,
  }) => _delegate.list(
    viewerId: viewerId != null && _session.permitsMember(viewerId)
        ? viewerId
        : null,
    includeTechnical: includeTechnical,
    limit: limit,
  );
}

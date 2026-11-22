import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_repository.dart';

class MessageController extends ChangeNotifier {
  MessageController(this._repository);

  final MessageStore _repository;

  List<Message> messages = const [];
  bool loading = true;
  bool pinnedOnly = false;
  int unreadCount = 0;
  String? viewerId;
  String? conversationId;
  String query = '';
  String? error;
  Timer? _searchDebounce;
  int _requestGeneration = 0;
  static const pageSize = 30;
  bool hasMore = false;
  bool loadingMore = false;

  Future<void> load({bool showLoading = false}) async {
    if (conversationId == null) {
      messages = const [];
      unreadCount = 0;
      loading = false;
      error = null;
      notifyListeners();
      return;
    }
    final generation = ++_requestGeneration;
    final shouldShowLoading = showLoading && messages.isEmpty;
    loading = shouldShowLoading;
    error = null;
    if (shouldShowLoading) notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.watchSnapshot(
          conversationId: conversationId!,
          query: query,
          pinnedOnly: pinnedOnly,
          viewerId: viewerId,
          limit: pageSize + 1,
        ),
        viewerId == null
            ? Future<int>.value(0)
            : _repository.unreadCount(
                conversationId: conversationId!,
                memberId: viewerId!,
              ),
      ]);
      if (generation != _requestGeneration) return;
      final page = results[0] as List<Message>;
      hasMore = page.length > pageSize;
      messages = page.take(pageSize).toList(growable: false);
      unreadCount = results[1] as int;
    } catch (exception) {
      if (generation != _requestGeneration) return;
      error = exception.toString();
    } finally {
      if (generation == _requestGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading ||
        loadingMore ||
        !hasMore ||
        messages.isEmpty ||
        conversationId == null) {
      return;
    }
    loadingMore = true;
    notifyListeners();
    final generation = _requestGeneration;
    final oldest = messages.last;
    try {
      final page = await _repository.watchSnapshot(
        conversationId: conversationId!,
        query: query,
        pinnedOnly: pinnedOnly,
        viewerId: viewerId,
        before: MessageCursor(
          createdAt: oldest.createdAt,
          revisionId: oldest.revisionId,
        ),
        limit: pageSize + 1,
      );
      if (generation != _requestGeneration) return;
      hasMore = page.length > pageSize;
      final known = messages.map((message) => message.id).toSet();
      messages = [
        ...messages,
        ...page.take(pageSize).where((message) => known.add(message.id)),
      ];
    } catch (exception) {
      if (generation == _requestGeneration) error = exception.toString();
    } finally {
      if (generation == _requestGeneration) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  void search(String value) {
    query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), load);
  }

  Future<void> togglePinnedFilter() async {
    pinnedOnly = !pinnedOnly;
    notifyListeners();
    await load();
  }

  Future<void> setViewer(
    String? memberId, {
    bool reloadConversation = true,
  }) async {
    viewerId = memberId;
    if (!reloadConversation) {
      messages = const [];
      unreadCount = 0;
      hasMore = false;
      notifyListeners();
      return;
    }
    await load(showLoading: true);
  }

  Future<void> selectConversation(String? id) async {
    _searchDebounce?.cancel();
    _requestGeneration++;
    conversationId = id;
    query = '';
    pinnedOnly = false;
    messages = const [];
    hasMore = false;
    await load(showLoading: true);
  }

  Future<void> send(
    String text,
    String? authorId, {
    Set<String> recipientIds = const {},
  }) async {
    await _repository.create(
      conversationId: conversationId!,
      content: text,
      authorId: authorId,
      recipientIds: recipientIds,
    );
    await load();
  }

  Future<void> edit(Message message, String text, String? actorId) async {
    await _repository.edit(
      messageId: message.id,
      content: text,
      editedById: actorId,
    );
    await load();
  }

  Future<void> delete(Message message, String? actorId) async {
    await _repository.delete(messageId: message.id, deletedById: actorId);
    await load();
  }

  Future<void> togglePin(Message message, String? actorId) async {
    await _repository.setPinned(
      messageId: message.id,
      pinned: !message.isPinned,
      actorId: actorId,
    );
    await load();
  }

  Future<void> markSeen(Message message, String memberId) async {
    await _repository.markSeen(messageId: message.id, memberId: memberId);
    await load();
  }

  Future<List<MessageRevision>> history(Message message) =>
      _repository.history(message.id);

  Future<void> transfer({
    required Message message,
    required String targetConversationId,
    String? authorId,
  }) async {
    await _repository.create(
      conversationId: targetConversationId,
      content: message.text,
      authorId: authorId,
      sourceMessageId: message.id,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

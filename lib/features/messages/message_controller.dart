import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_repository.dart';

/// Presentation controller for one selected conversation.
///
/// Request generations prevent slower, stale loads from overwriting results
/// after a viewer, conversation, or search change. Pages use keyset cursors and
/// are deduplicated by logical message ID.
class MessageController extends ChangeNotifier {
  /// Creates a controller around the narrow [MessageStore] contract.
  MessageController(this._repository);

  final MessageStore _repository;

  /// Currently loaded newest-first message page(s).
  List<Message> messages = const [];

  /// Whether the first visible page is loading.
  bool loading = true;

  /// Whether only pinned messages are requested.
  bool pinnedOnly = false;

  /// Viewer-specific unread total for the selected conversation.
  int unreadCount = 0;

  /// Current viewer identity, or unknown when `null`.
  String? viewerId;

  /// Selected conversation, or `null` when no space is available.
  String? conversationId;

  /// Current case-insensitive search text.
  String query = '';

  /// Last repository error suitable for presentation.
  String? error;
  Timer? _searchDebounce;
  int _requestGeneration = 0;

  /// Number of visible messages retained per page.
  static const pageSize = 30;

  /// Whether another keyset page may exist.
  bool hasMore = false;

  /// Whether an additional page is currently loading.
  bool loadingMore = false;

  /// Prepares encrypted persistence before workspace data is displayed.
  Future<void> prepare() => _repository.prepare();

  /// Reloads the first page for the current selection and filters.
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

  /// Appends the next page without duplicating already loaded messages.
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

  /// Debounces a new in-memory encrypted-content search.
  void search(String value) {
    query = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), load);
  }

  /// Switches between the full and pinned-only projections.
  Future<void> togglePinnedFilter() async {
    pinnedOnly = !pinnedOnly;
    notifyListeners();
    await load();
  }

  /// Changes the identity used for visibility, receipts, and unread counts.
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

  /// Immediately removes viewer-scoped plaintext and invalidates stale loads.
  void clearSensitiveCache() {
    _searchDebounce?.cancel();
    _requestGeneration++;
    viewerId = null;
    messages = const [];
    unreadCount = 0;
    query = '';
    pinnedOnly = false;
    hasMore = false;
    loadingMore = false;
    error = null;
    notifyListeners();
  }

  /// Selects a conversation and resets conversation-scoped filters/pages.
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

  /// Sends a message and refreshes the current projection.
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

  /// Appends an edit revision and refreshes the current projection.
  Future<void> edit(Message message, String text, String? actorId) async {
    await _repository.edit(
      messageId: message.id,
      content: text,
      editedById: actorId,
    );
    await load();
  }

  /// Appends a deletion tombstone and refreshes the current projection.
  Future<void> delete(Message message, String? actorId) async {
    await _repository.delete(messageId: message.id, deletedById: actorId);
    await load();
  }

  /// Toggles the logical message pin and refreshes the projection.
  Future<void> togglePin(Message message, String? actorId) async {
    await _repository.setPinned(
      messageId: message.id,
      pinned: !message.isPinned,
      actorId: actorId,
    );
    await load();
  }

  /// Records a member acknowledgement and refreshes unread state.
  Future<void> markSeen(Message message, String memberId) async {
    await _repository.markSeen(messageId: message.id, memberId: memberId);
    await load();
  }

  /// Loads the complete immutable revision history for [message].
  Future<List<MessageRevision>> history(Message message) =>
      _repository.history(message.id, viewerId: viewerId);

  /// Copies decrypted content into another space with a source relationship.
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

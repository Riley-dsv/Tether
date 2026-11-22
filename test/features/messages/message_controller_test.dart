import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_controller.dart';
import 'package:note_app/features/messages/message_repository.dart';

void main() {
  test('loads message history in stable pages', () async {
    final store = _PagedMessageStore(65);
    final controller = MessageController(store)..viewerId = 'viewer';
    addTearDown(controller.dispose);

    await controller.selectConversation('general');
    expect(controller.messages, hasLength(30));
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.messages, hasLength(60));
    expect(
      controller.messages.map((message) => message.id).toSet(),
      hasLength(60),
    );

    await controller.loadMore();
    expect(controller.messages, hasLength(65));
    expect(controller.hasMore, isFalse);
    expect(controller.messages.last.text, 'Message 0');
  });
}

class _PagedMessageStore implements MessageStore {
  _PagedMessageStore(int count)
    : messages = List.generate(count, (index) {
        final revisionId = index + 1;
        return Message(
          id: 'message_$index',
          revisionId: revisionId,
          author: null,
          text: 'Message $index',
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
          revision: 1,
          isPinned: false,
          seenBy: const {},
          seenByNames: const [],
          visibility: MessageVisibility.shared,
          recipientIds: const {},
          recipientNames: const [],
        );
      }).reversed.toList();

  final List<Message> messages;

  @override
  Future<List<Message>> watchSnapshot({
    required String conversationId,
    String query = '',
    bool pinnedOnly = false,
    String? viewerId,
    MessageCursor? before,
    int? limit,
  }) async {
    var start = 0;
    if (before != null) {
      start =
          messages.indexWhere(
            (message) => message.revisionId == before.revisionId,
          ) +
          1;
    }
    final page = messages.skip(start);
    return (limit == null ? page : page.take(limit)).toList();
  }

  @override
  Future<int> unreadCount({
    required String conversationId,
    required String memberId,
  }) async => 0;
  @override
  Future<Message> create({
    required String conversationId,
    required String content,
    String? authorId,
    Set<String> recipientIds = const {},
    String? sourceMessageId,
  }) => throw UnimplementedError();
  @override
  Future<void> delete({required String messageId, String? deletedById}) =>
      throw UnimplementedError();
  @override
  Future<void> edit({
    required String messageId,
    required String content,
    String? editedById,
  }) => throw UnimplementedError();
  @override
  Future<List<MessageRevision>> history(String messageId) =>
      throw UnimplementedError();
  @override
  Future<void> markSeen({
    required String messageId,
    required String memberId,
  }) => throw UnimplementedError();
  @override
  Future<void> setPinned({
    required String messageId,
    required bool pinned,
    String? actorId,
  }) => throw UnimplementedError();
}

import 'package:flutter_test/flutter_test.dart';
import 'package:note_app/features/home/home_repository.dart';
import 'package:note_app/features/home/home_summary.dart';
import 'package:note_app/features/members/member_session.dart';
import 'package:note_app/features/members/session_bound_stores.dart';
import 'package:note_app/features/members/system_member.dart';
import 'package:note_app/features/messages/message.dart';
import 'package:note_app/features/messages/message_notification_policy.dart';
import 'package:note_app/features/messages/message_repository.dart';
import 'package:note_app/features/system_log/system_event.dart';
import 'package:note_app/features/system_log/system_log_repository.dart';

void main() {
  final alice = SystemMember.fromStorage(id: 'alice', name: 'Alice');

  test('message reads cannot claim an inactive member viewer', () async {
    final session = MemberSession();
    final delegate = _ProbeMessageStore();
    final store = SessionBoundMessageStore(delegate, session);

    await store.watchSnapshot(conversationId: 'private', viewerId: alice.id);
    expect(delegate.lastViewerId, isNull);

    session.activate(alice);
    await store.watchSnapshot(conversationId: 'private', viewerId: alice.id);
    expect(delegate.lastViewerId, alice.id);

    session.useAnonymous();
    await store.history('message', viewerId: alice.id);
    expect(delegate.lastViewerId, isNull);
  });

  test('message mutations reject unauthenticated member attribution', () async {
    final session = MemberSession();
    final delegate = _ProbeMessageStore();
    final store = SessionBoundMessageStore(delegate, session);

    expect(
      () => store.create(
        conversationId: 'space',
        content: 'secret',
        authorId: alice.id,
      ),
      throwsStateError,
    );
    expect(delegate.createCalls, 0);

    session.activate(alice);
    await store.create(
      conversationId: 'space',
      content: 'allowed',
      authorId: alice.id,
    );
    expect(delegate.createCalls, 1);
  });

  test('home and system log fail closed after session revocation', () async {
    final session = MemberSession();
    final home = SessionBoundHomeStore(_ProbeHomeStore(), session);
    final logDelegate = _ProbeSystemLogStore();
    final log = SessionBoundSystemLogStore(logDelegate, session);

    expect((await home.summary(viewerId: alice.id)).unreadMessages, 0);
    await log.list(viewerId: alice.id);
    expect(logDelegate.lastViewerId, isNull);

    session.activate(alice);
    expect((await home.summary(viewerId: alice.id)).unreadMessages, 7);
    await log.list(viewerId: alice.id);
    expect(logDelegate.lastViewerId, alice.id);

    session.useAnonymous();
    expect((await home.summary(viewerId: alice.id)).unreadMessages, 0);
  });

  test('notification preview derives permission from the session', () {
    final session = MemberSession();
    final policy = SessionBoundNotificationPolicy(session);
    final message = _privateMessage(alice);

    expect(policy.preview(message), 'New protected message');
    session.activate(alice);
    expect(policy.preview(message), message.text);
    session.useAnonymous();
    expect(policy.preview(message), 'New protected message');
  });
}

Message _privateMessage(SystemMember recipient) => Message(
  id: 'message',
  revisionId: 1,
  author: null,
  text: 'private content',
  createdAt: DateTime.utc(2026),
  revision: 1,
  isPinned: false,
  seenBy: const {},
  seenByNames: const [],
  visibility: MessageVisibility.private,
  recipientIds: {recipient.id},
  recipientNames: [recipient.name],
);

class _ProbeHomeStore implements HomeStore {
  @override
  Future<HomeSummary> summary({required String? viewerId}) async =>
      viewerId == null
      ? const HomeSummary.empty()
      : const HomeSummary(
          unreadMessages: 7,
          importantHandovers: 2,
          tasksToday: 1,
        );
}

class _ProbeSystemLogStore implements SystemLogStore {
  String? lastViewerId;

  @override
  Future<List<SystemEvent>> list({
    String? viewerId,
    bool includeTechnical = false,
    int limit = 250,
  }) async {
    lastViewerId = viewerId;
    return const [];
  }
}

class _ProbeMessageStore implements MessageStore {
  String? lastViewerId;
  int createCalls = 0;

  @override
  Future<void> prepare() async {}

  @override
  Future<List<Message>> watchSnapshot({
    required String conversationId,
    String query = '',
    bool pinnedOnly = false,
    String? viewerId,
    MessageCursor? before,
    int? limit,
  }) async {
    lastViewerId = viewerId;
    return const [];
  }

  @override
  Future<List<MessageRevision>> history(
    String messageId, {
    String? viewerId,
  }) async {
    lastViewerId = viewerId;
    return const [];
  }

  @override
  Future<Message> create({
    required String conversationId,
    required String content,
    String? authorId,
    Set<String> recipientIds = const {},
    String? sourceMessageId,
  }) async {
    createCalls++;
    return _privateMessage(
      SystemMember.fromStorage(id: authorId ?? 'unknown', name: 'Author'),
    );
  }

  @override
  Future<void> delete({required String messageId, String? deletedById}) async {}

  @override
  Future<void> edit({
    required String messageId,
    required String content,
    String? editedById,
  }) async {}

  @override
  Future<void> markSeen({
    required String messageId,
    required String memberId,
  }) async {}

  @override
  Future<void> setPinned({
    required String messageId,
    required bool pinned,
    String? actorId,
  }) async {}

  @override
  Future<int> unreadCount({
    required String conversationId,
    required String memberId,
  }) async => 0;
}

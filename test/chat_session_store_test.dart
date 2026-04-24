import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_session_store.dart';

void main() {
  test('startSession selects and persists the new chat', () async {
    final saved = <ChatSession>[];
    final store = ChatSessionStore(
      loadAllChats: () async => <ChatSession>[],
      saveChat: (session) async => saved.add(session),
      deleteChat: (_) async {},
      clearAllChats: () async {},
    );

    final session = await store.startSession('Hello world');

    expect(store.selectedSession?.id, session.id);
    expect(store.sessions, hasLength(1));
    expect(saved.single.title, 'Hello world');
    expect(saved.single.messages.single.role, 'user');
  });

  test('addUserMessage and appendAssistantMessage update selected session',
      () async {
    final store = ChatSessionStore(
      loadAllChats: () async => <ChatSession>[],
      saveChat: (_) async {},
      deleteChat: (_) async {},
      clearAllChats: () async {},
    );

    await store.startSession('First');
    store.addUserMessage('Second');
    await store.appendAssistantMessage('Reply');

    final messages = store.selectedSession?.messages ?? const <ChatMessage>[];
    expect(messages.map((item) => item.role).toList(),
        ['user', 'user', 'assistant']);
  });

  test('prepareLastUserMessageEdit returns draft without mutating history',
      () async {
    final store = ChatSessionStore(
      loadAllChats: () async => <ChatSession>[],
      saveChat: (_) async {},
      deleteChat: (_) async {},
      clearAllChats: () async {},
    );

    await store.startSession('First');
    store.addUserMessage('Second');
    await store.appendAssistantMessage('Reply');
    final messageId = store.selectedSession!.messages[1].id;

    final draft = store.prepareLastUserMessageEdit(messageId);

    expect(draft, 'Second');
    expect(store.selectedSession!.messages, hasLength(3));
    expect(store.selectedSession!.messages.last.content, 'Reply');
  });

  test(
      'replaceLastUserMessageTurn swaps last user turn and removes last assistant',
      () async {
    final store = ChatSessionStore(
      loadAllChats: () async => <ChatSession>[],
      saveChat: (_) async {},
      deleteChat: (_) async {},
      clearAllChats: () async {},
    );

    await store.startSession('Apple kya hai?');
    await store.appendAssistantMessage('Apple ek phal hai...');
    final userMessageId = store.selectedSession!.messages.first.id;

    final updated = store.replaceLastUserMessageTurn(
      userMessageId,
      'Apple company kya hai?',
    );

    expect(updated, isNotNull);
    expect(updated!.messages, hasLength(1));
    expect(updated.messages.single.role, 'user');
    expect(updated.messages.single.content, 'Apple company kya hai?');
    expect(updated.messages.single.promptText, 'Apple company kya hai?');
    expect(updated.title, 'Apple company kya hai?');
  });

  test(
      'prepareLastUserMessageEdit rejects non-last messages and allows attachments',
      () async {
    final store = ChatSessionStore(
      loadAllChats: () async => <ChatSession>[],
      saveChat: (_) async {},
      deleteChat: (_) async {},
      clearAllChats: () async {},
    );

    await store.startSession('First');
    store.addUserMessage(
      'Second',
      attachments: const [
        ChatAttachment(
          name: 'notes.txt',
          type: ComposerAttachmentType.textFile,
          extractedText: 'hello',
        ),
      ],
    );
    await store.appendAssistantMessage('Reply');

    expect(
      store
          .prepareLastUserMessageEdit(store.selectedSession!.messages.first.id),
      isNull,
    );
    expect(
      store.prepareLastUserMessageEdit(store.selectedSession!.messages[1].id),
      'Second',
    );
  });

  test(
      'pinned chats stay at the top and replacing another chat keeps selection',
      () async {
    final store = ChatSessionStore(
      loadAllChats: () async => <ChatSession>[],
      saveChat: (_) async {},
      deleteChat: (_) async {},
      clearAllChats: () async {},
    );

    await store.startSession('Older chat');
    final firstSession = store.selectedSession!;

    await Future<void>.delayed(const Duration(milliseconds: 1));
    await store.startSession('Newer chat');
    final secondSession = store.selectedSession!;

    store.selectSession(secondSession);
    store.replaceSession(
      firstSession.copyWith(
        isPinned: true,
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    );

    expect(store.selectedSession?.id, secondSession.id);
    expect(store.sessions.first.id, firstSession.id);
    expect(store.sessions.first.isPinned, isTrue);
  });
}

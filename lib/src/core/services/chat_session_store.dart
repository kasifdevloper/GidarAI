import 'dart:async';

import '../models/app_descriptors.dart';
import '../models/app_models.dart';

class ChatSessionStore {
  ChatSessionStore({
    required Future<List<ChatSession>> Function() loadAllChats,
    required Future<void> Function(ChatSession session) saveChat,
    required Future<void> Function(String id) deleteChat,
    required Future<void> Function() clearAllChats,
  })  : _loadAllChats = loadAllChats,
        _saveChat = saveChat,
        _deleteChat = deleteChat,
        _clearAllChats = clearAllChats;

  final Future<List<ChatSession>> Function() _loadAllChats;
  final Future<void> Function(ChatSession session) _saveChat;
  final Future<void> Function(String id) _deleteChat;
  final Future<void> Function() _clearAllChats;

  List<ChatSession> _sessions = [];
  ChatSession? _selectedSession;
  int _localIdSeed = 0;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  ChatSession? get selectedSession => _selectedSession;

  Future<void> load() async {
    _sessions = await _loadAllChats()
      ..sort(compareChatSessions);
    _selectedSession = _sessions.isNotEmpty ? _sessions.first : null;
  }

  void reset({List<ChatSession>? sessions, ChatSession? selectedSession}) {
    _sessions = List<ChatSession>.from(sessions ?? <ChatSession>[])
      ..sort(compareChatSessions);
    final selectedId = selectedSession?.id;
    _selectedSession =
        selectedId == null ? null : sessionForId(selectedId) ?? selectedSession;
  }

  void selectSession(ChatSession session) {
    _selectedSession = sessionForId(session.id) ?? session;
  }

  ChatSession? sessionForId(String id) {
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  List<ChatSession> filteredSessions(String query) {
    if (query.trim().isEmpty) return sessions;
    final normalized = query.trim().toLowerCase();
    return _sessions.where((session) {
      final haystack = '${session.title} ${session.preview}'.toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  Future<ChatSession> startSession(
    String prompt, {
    String? displayContent,
    List<ChatAttachment> attachments = const [],
  }) async {
    final normalizedPrompt = prompt.trim();
    final userMessage = ChatMessage(
      id: _nextId('user'),
      role: 'user',
      content: displayContent ?? normalizedPrompt,
      createdAt: DateTime.now(),
      requestText: normalizedPrompt,
      attachments: attachments,
    );
    final session = ChatSession(
      id: _nextId('session'),
      title: buildChatTitle(normalizedPrompt),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [userMessage],
    );
    _sessions = [session, ..._sessions];
    _selectedSession = session;
    await _saveChat(session);
    return session;
  }

  ChatSession? addUserMessage(
    String text, {
    String? displayContent,
    List<ChatAttachment> attachments = const [],
  }) {
    final session = _selectedSession;
    if (session == null) return null;

    final userMessage = ChatMessage(
      id: _nextId('user'),
      role: 'user',
      content: displayContent ?? text,
      createdAt: DateTime.now(),
      requestText: text,
      attachments: attachments,
    );
    final updatedMessages = [...session.messages, userMessage];
    final updated = session.copyWith(
      title: session.messages.isEmpty ? buildChatTitle(text) : session.title,
      updatedAt: DateTime.now(),
      messages: updatedMessages,
    );
    replaceSession(updated);
    return updated;
  }

  Future<String?> extractRetryPrompt() async {
    final session = _selectedSession;
    if (session == null) return null;

    final messages = [...session.messages];
    while (messages.isNotEmpty && messages.last.role == 'assistant') {
      messages.removeLast();
    }
    if (messages.isEmpty || messages.last.role != 'user') return null;

    final retryPrompt = messages.removeLast().promptText;
    replaceSession(
      session.copyWith(
        updatedAt: DateTime.now(),
        messages: messages,
      ),
      persist: false,
    );
    await saveSelectedSession();
    return retryPrompt;
  }

  Future<void> setAssistantFeedback(
    String messageId,
    MessageFeedback feedback,
  ) async {
    final session = _selectedSession;
    if (session == null) return;

    final updatedMessages = session.messages.map((message) {
      if (message.id != messageId) return message;
      return message.copyWith(
        feedback: message.feedback == feedback ? null : feedback,
      );
    }).toList();

    replaceSession(
      session.copyWith(
        updatedAt: DateTime.now(),
        messages: updatedMessages,
      ),
      persist: false,
    );
    await saveSelectedSession();
  }

  String? prepareLastUserMessageEdit(String messageId) {
    final session = _selectedSession;
    if (session == null) return null;

    final index =
        session.messages.indexWhere((message) => message.id == messageId);
    if (!_canEditLastUserMessage(session, targetIndex: index)) return null;
    return session.messages[index].promptText;
  }

  ChatSession? replaceLastUserMessageTurn(
    String messageId,
    String text, {
    String? displayContent,
    List<ChatAttachment> attachments = const [],
  }) {
    final session = _selectedSession;
    if (session == null) return null;

    final normalizedText = text.trim();
    if (normalizedText.isEmpty) return null;

    final index =
        session.messages.indexWhere((message) => message.id == messageId);
    if (!_canEditLastUserMessage(session, targetIndex: index)) return null;

    final updatedMessages = session.messages.take(index + 1).toList();
    final originalUserMessage = updatedMessages[index];
    updatedMessages[index] = originalUserMessage.copyWith(
      content: displayContent ?? normalizedText,
      requestText: normalizedText,
      attachments: attachments,
    );

    final updated = session.copyWith(
      title: index == 0 ? buildChatTitle(normalizedText) : session.title,
      updatedAt: DateTime.now(),
      messages: updatedMessages,
    );
    replaceSession(updated);
    return updated;
  }

  Future<void> appendAssistantMessage(String content) async {
    final session = _selectedSession;
    if (session == null || content.trim().isEmpty) return;
    await appendAssistantMessageToSession(session.id, content);
  }

  Future<void> appendAssistantMessageToSession(
    String sessionId,
    String content,
  ) async {
    final session = sessionForId(sessionId);
    if (session == null || content.trim().isEmpty) return;

    final assistantMessage = ChatMessage(
      id: _nextId('assistant'),
      role: 'assistant',
      content: content,
      createdAt: DateTime.now(),
    );
    final finalized = session.copyWith(
      updatedAt: DateTime.now(),
      messages: [...session.messages, assistantMessage],
    );
    replaceSession(finalized, persist: false);
    await saveSessionById(sessionId);
  }

  Future<void> saveSelectedSession() async {
    final session = _selectedSession;
    if (session == null) return;
    await saveSessionById(session.id);
  }

  Future<void> saveSessionById(String sessionId) async {
    final session = sessionForId(sessionId);
    if (session == null) return;
    await _saveChat(session);
  }

  Future<void> clearCurrentChat() async {
    final targetId = _selectedSession?.id;
    if (targetId == null) return;
    _sessions.removeWhere((session) => session.id == targetId);
    _selectedSession = _sessions.isNotEmpty ? _sessions.first : null;
    await _deleteChat(targetId);
  }

  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((session) => session.id == id);
    if (_selectedSession?.id == id) {
      _selectedSession = _sessions.isNotEmpty ? _sessions.first : null;
    }
    await _deleteChat(id);
  }

  Future<void> clearAll() async {
    _sessions = [];
    _selectedSession = null;
    await _clearAllChats();
  }

  void replaceSession(ChatSession updated, {bool persist = true}) {
    final selectedId = _selectedSession?.id;
    _sessions = [
      updated,
      ..._sessions.where((session) => session.id != updated.id),
    ]..sort(compareChatSessions);
    if (selectedId == null) {
      _selectedSession = null;
    } else {
      _selectedSession = sessionForId(selectedId);
    }
    if (persist) {
      unawaited(_saveChat(updated));
    }
  }

  String _nextId(String suffix) {
    _localIdSeed += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-${_localIdSeed}_$suffix';
  }

  bool _canEditLastUserMessage(
    ChatSession session, {
    required int targetIndex,
  }) {
    if (targetIndex == -1) return false;
    final target = session.messages[targetIndex];
    if (target.role != 'user') return false;

    final lastUserIndex =
        session.messages.lastIndexWhere((message) => message.role == 'user');
    if (lastUserIndex != targetIndex) return false;

    for (final trailingMessage in session.messages.skip(targetIndex + 1)) {
      if (trailingMessage.role != 'assistant') {
        return false;
      }
    }
    return true;
  }
}

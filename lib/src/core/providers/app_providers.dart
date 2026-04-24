import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_models.dart';
import '../services/app_controller.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  throw UnimplementedError(
      'appControllerProvider must be overridden at the app root.');
});

class ChatActions {
  ChatActions(this._controller);

  final AppController _controller;

  Future<void> sendPrompt(
    String input, {
    String? displayPrompt,
    List<ChatAttachment> attachments = const [],
  }) {
    return _controller.sendMessage(
      input,
      displayPrompt: displayPrompt,
      attachments: attachments,
    );
  }

  Future<void> sendEditedPrompt(
    String messageId,
    String input, {
    String? displayPrompt,
    List<ChatAttachment> attachments = const [],
  }) {
    return _controller.sendEditedMessage(
      messageId,
      input,
      displayPrompt: displayPrompt,
      attachments: attachments,
    );
  }

  Future<void> copyLastAssistantMessage() =>
      _controller.copyLastAssistantMessage();

  Future<void> retryLastAssistantMessage() =>
      _controller.retryLastAssistantMessage();

  Future<void> stopStreaming() => _controller.stopStreaming();

  String? prepareLastUserMessageEdit(String messageId) {
    return _controller.prepareLastUserMessageEdit(messageId);
  }

  Future<void> setAssistantFeedback(
    String messageId,
    MessageFeedback feedback,
  ) {
    return _controller.setAssistantFeedback(messageId, feedback);
  }

  Future<void> toggleStarred() => _controller.toggleStarred();

  String? getChatAsText() {
    final session = _controller.selectedSession;
    if (session == null) return null;
    final buffer = StringBuffer();
    buffer.writeln(session.title);
    buffer.writeln('');
    for (final message in session.messages) {
      final role = message.role == 'user' ? 'You' : 'Gidar AI';
      buffer.writeln('[$role]');
      buffer.writeln(message.content);
      buffer.writeln('');
    }
    return buffer.toString().trim();
  }
}

final chatActionsProvider = Provider<ChatActions>(
  (ref) {
    final controller = ref.watch(appControllerProvider);
    return ChatActions(controller);
  },
  dependencies: [appControllerProvider],
);

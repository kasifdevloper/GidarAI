import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';

class ChatViewModel {
  const ChatViewModel({
    required this.session,
    required this.messages,
    required this.isStreaming,
    required this.title,
    required this.contextUsageLabel,
  });

  final ChatSession? session;
  final List<ChatMessage> messages;
  final bool isStreaming;
  final String title;
  final String contextUsageLabel;
}

final chatViewModelProvider = Provider<ChatViewModel>(
  (ref) {
    final controller = ref.watch(appControllerProvider);
    final session = controller.selectedSession;
    final messages = [...?session?.messages];

    return ChatViewModel(
      session: session,
      messages: messages,
      isStreaming: controller.isStreaming,
      title: session?.title ?? 'Gidar AI',
      contextUsageLabel: 'Context: ${messages.length.clamp(0, 20)}/20',
    );
  },
  dependencies: [appControllerProvider],
);

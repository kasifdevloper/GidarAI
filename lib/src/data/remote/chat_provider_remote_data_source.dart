import '../../core/models/app_models.dart';

abstract class ChatProviderRemoteDataSource {
  AiProviderType get provider;

  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  });

  void dispose();
}

extension ChatHistoryWindow on List<ChatMessage> {
  Iterable<ChatMessage> takeLast(int count) {
    if (length <= count) return this;
    return skip(length - count);
  }
}

extension ChatMessagePayload on ChatMessage {
  String toPlainTextPrompt() {
    final buffer = StringBuffer(promptText);
    if (attachments.isEmpty) {
      return buffer.toString().trim();
    }

    buffer.writeln();
    buffer.writeln();
    buffer.writeln('Attachments:');
    for (final attachment in attachments) {
      buffer.writeln('- ${attachment.name}');
      buffer.writeln('[Image attached: ${attachment.name}]');
    }
    return buffer.toString().trim();
  }

  Object toOpenAiCompatibleContent({required bool supportsVision}) {
    if (!supportsVision || attachments.isEmpty) {
      return toPlainTextPrompt();
    }

    final parts = <Map<String, dynamic>>[
      {'type': 'text', 'text': promptText},
    ];
    for (final attachment in attachments) {
      if (attachment.type == ComposerAttachmentType.image &&
          attachment.hasInlineData &&
          attachment.mediaType != null) {
        parts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:${attachment.mediaType};base64,${attachment.inlineDataBase64}',
          },
        });
        continue;
      }
      parts.add({
        'type': 'text',
        'text': _attachmentTextPart(attachment),
      });
    }
    return parts;
  }

  Map<String, dynamic> toGeminiContent({required bool supportsVision}) {
    if (!supportsVision || attachments.isEmpty) {
      return {
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': toPlainTextPrompt()},
        ],
      };
    }

    final parts = <Map<String, dynamic>>[
      {'text': promptText},
    ];
    for (final attachment in attachments) {
      if (attachment.type == ComposerAttachmentType.image &&
          attachment.hasInlineData &&
          attachment.mediaType != null) {
        parts.add({
          'inline_data': {
            'mime_type': attachment.mediaType,
            'data': attachment.inlineDataBase64,
          },
        });
        continue;
      }
      parts.add({
        'text': _attachmentTextPart(attachment),
      });
    }
    return {
      'role': role == 'assistant' ? 'model' : 'user',
      'parts': parts,
    };
  }
}

String _attachmentTextPart(ChatAttachment attachment) {
  return '[Image attached: ${attachment.name}]';
}

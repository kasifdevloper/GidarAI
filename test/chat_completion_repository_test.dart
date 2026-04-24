import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/data/remote/gemini_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/remote/groq_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/remote/openrouter_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/remote/zai_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/repository/chat_completion_repository.dart';

void main() {
  test('repository preserves multimodal history for the selected provider',
      () async {
    late List<ChatMessage> capturedHistory;
    late ModelOption capturedModel;
    late String capturedSystemPrompt;

    final repository = ChatCompletionRepository(
      openRouterRemoteDataSource: _FakeOpenRouterRemoteDataSource(
        onStream: ({
          required apiKey,
          required model,
          required systemPrompt,
          required history,
        }) {
          capturedHistory = history;
          capturedModel = model;
          capturedSystemPrompt = systemPrompt;
          return Stream<String>.fromIterable(const ['All good']);
        },
      ),
      groqRemoteDataSource: _FakeGroqRemoteDataSource.empty(),
      geminiRemoteDataSource: _FakeGeminiRemoteDataSource.empty(),
      zaiRemoteDataSource: _FakeZaiRemoteDataSource.empty(),
    );

    final selectedModel = const ModelOption(
      name: 'Vision Model',
      id: 'vision-model',
      blurb: 'test',
      provider: AiProviderType.openRouter,
      supportsVision: true,
    );
    final history = [
      ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'Please review the attachment',
        requestText: 'Please review the attachment',
        createdAt: DateTime(2026, 1, 1),
        attachments: const [
          ChatAttachment(
            name: 'diagram.png',
            type: ComposerAttachmentType.image,
            mediaType: 'image/png',
            inlineDataBase64: 'abc123',
          ),
        ],
      ),
    ];

    final chunks = await repository
        .streamChatCompletion(
          providerKeys: const ProviderKeys(openRouter: 'or-key'),
          customProviders: const <CustomProviderConfig>[],
          model: selectedModel,
          routingMode: ChatRoutingMode.directModel,
          enabledProviders: const [AiProviderType.openRouter],
          systemPrompt: 'Stay concise.',
          history: history,
        )
        .toList();

    expect(chunks.join(), 'All good');
    expect(capturedModel.id, selectedModel.id);
    expect(capturedSystemPrompt, 'Stay concise.');
    expect(capturedHistory.single.promptText, 'Please review the attachment');
    expect(capturedHistory.single.attachments, hasLength(1));
    expect(capturedHistory.single.attachments.single.mediaType, 'image/png');
  });

  test('repository falls back to the next provider and emits notices',
      () async {
    final providerSelections = <String>[];
    final notices = <String>[];
    late List<ChatMessage> fallbackHistory;

    final repository = ChatCompletionRepository(
      openRouterRemoteDataSource: _FakeOpenRouterRemoteDataSource.empty(),
      groqRemoteDataSource: _FakeGroqRemoteDataSource.empty(),
      geminiRemoteDataSource: _FakeGeminiRemoteDataSource(
        onStream: ({
          required apiKey,
          required model,
          required systemPrompt,
          required history,
        }) {
          throw const ProviderChatException(
            provider: AiProviderType.gemini,
            message: 'Gemini failed',
          );
        },
      ),
      zaiRemoteDataSource: _FakeZaiRemoteDataSource(
        onStream: ({
          required apiKey,
          required model,
          required systemPrompt,
          required history,
        }) {
          fallbackHistory = history;
          return Stream<String>.fromIterable(const ['Fallback reply']);
        },
      ),
    );

    final selectedModel = const ModelOption(
      name: 'Gemini Vision',
      id: 'gemini-vision',
      blurb: 'test',
      provider: AiProviderType.gemini,
      supportsVision: true,
    );
    final history = [
      ChatMessage(
        id: 'u1',
        role: 'user',
        content: 'What is in this image?',
        requestText: 'What is in this image?',
        createdAt: DateTime(2026, 1, 1),
        attachments: const [
          ChatAttachment(
            name: 'photo.png',
            type: ComposerAttachmentType.image,
            mediaType: 'image/png',
            inlineDataBase64: 'xyz789',
          ),
        ],
      ),
    ];

    final chunks = await repository
        .streamChatCompletion(
          providerKeys: const ProviderKeys(gemini: 'g-key', zAi: 'z-key'),
          customProviders: const <CustomProviderConfig>[],
          model: selectedModel,
          routingMode: ChatRoutingMode.autoVision,
          enabledProviders: const [AiProviderType.gemini, AiProviderType.zAi],
          systemPrompt: 'Describe visuals.',
          history: history,
          onProviderSelected: (provider, model) {
            providerSelections.add('${provider.name}:${model.provider.name}');
          },
          onProviderNotice: notices.add,
        )
        .toList();

    expect(chunks.join(), 'Fallback reply');
    expect(providerSelections, [
      'gemini:gemini',
      'zAi:zAi',
    ]);
    expect(notices.first, contains('Using Gemini'));
    expect(notices, contains('Switching from Gemini to Z.ai'));
    expect(notices.last, contains('Using Z.ai'));
    expect(
        fallbackHistory.single.attachments.single.inlineDataBase64, 'xyz789');
  });
}

typedef _OnStream = Stream<String> Function({
  required String apiKey,
  required ModelOption model,
  required String systemPrompt,
  required List<ChatMessage> history,
});

class _FakeOpenRouterRemoteDataSource extends OpenRouterRemoteDataSource {
  _FakeOpenRouterRemoteDataSource({required _OnStream onStream})
      : _onStream = onStream;

  _FakeOpenRouterRemoteDataSource.empty() : _onStream = _emptyStream;

  final _OnStream _onStream;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return _onStream(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  @override
  void dispose() {}
}

class _FakeGroqRemoteDataSource extends GroqRemoteDataSource {
  _FakeGroqRemoteDataSource({required _OnStream onStream})
      : _onStream = onStream;

  _FakeGroqRemoteDataSource.empty() : _onStream = _emptyStream;

  final _OnStream _onStream;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return _onStream(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  @override
  void dispose() {}
}

class _FakeGeminiRemoteDataSource extends GeminiRemoteDataSource {
  _FakeGeminiRemoteDataSource({required _OnStream onStream})
      : _onStream = onStream;

  _FakeGeminiRemoteDataSource.empty() : _onStream = _emptyStream;

  final _OnStream _onStream;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return _onStream(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  @override
  void dispose() {}
}

class _FakeZaiRemoteDataSource extends ZaiRemoteDataSource {
  _FakeZaiRemoteDataSource({required _OnStream onStream})
      : _onStream = onStream;

  _FakeZaiRemoteDataSource.empty() : _onStream = _emptyStream;

  final _OnStream _onStream;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return _onStream(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  @override
  void dispose() {}
}

Stream<String> _emptyStream({
  required String apiKey,
  required ModelOption model,
  required String systemPrompt,
  required List<ChatMessage> history,
}) {
  return const Stream<String>.empty();
}

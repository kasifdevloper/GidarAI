import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/data/remote/chat_provider_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/remote/gemini_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/remote/groq_remote_data_source.dart';

void main() {
  test('plain text payload falls back to image attachment markers', () {
    final message = ChatMessage(
      id: 'm1',
      role: 'user',
      content: 'Summarize this',
      requestText: 'Summarize this',
      createdAt: DateTime(2026),
      attachments: const [
        ChatAttachment(
          name: 'first.png',
          type: ComposerAttachmentType.image,
          mediaType: 'image/png',
          inlineDataBase64: 'abc123',
        ),
        ChatAttachment(
          name: 'second.png',
          type: ComposerAttachmentType.image,
          mediaType: 'image/png',
          inlineDataBase64: 'def456',
        ),
      ],
    );

    final payload = message.toPlainTextPrompt();
    expect(payload, contains('Summarize this'));
    expect(payload, contains('Attachments:'));
    expect(payload, contains('first.png'));
    expect(payload, contains('[Image attached: first.png]'));
    expect(payload, contains('[Image attached: second.png]'));
  });

  test('openai compatible payload sends images as data urls when vision is supported', () {
    final message = ChatMessage(
      id: 'm2',
      role: 'user',
      content: 'What is in this image?',
      requestText: 'What is in this image?',
      createdAt: DateTime(2026),
      attachments: const [
        ChatAttachment(
          name: 'diagram.png',
          type: ComposerAttachmentType.image,
          mediaType: 'image/png',
          inlineDataBase64: 'abc123',
        ),
        ChatAttachment(
          name: 'scene.jpg',
          type: ComposerAttachmentType.image,
          mediaType: 'image/jpeg',
          inlineDataBase64: 'xyz789',
        ),
      ],
    );

    final payload =
        message.toOpenAiCompatibleContent(supportsVision: true) as List<Map<String, dynamic>>;

    expect(payload.first['text'], 'What is in this image?');
    expect(payload[1]['image_url']['url'], 'data:image/png;base64,abc123');
    expect(payload[2]['image_url']['url'], 'data:image/jpeg;base64,xyz789');
  });

  test('gemini payload keeps fallback image text when vision is unavailable', () {
    final message = ChatMessage(
      id: 'm3',
      role: 'user',
      content: 'Review this file',
      requestText: 'Review this file',
      createdAt: DateTime(2026),
      attachments: const [
        ChatAttachment(
          name: 'notes.png',
          type: ComposerAttachmentType.image,
          mediaType: 'image/png',
          inlineDataBase64: 'abc123',
        ),
      ],
    );

    final payload = message.toGeminiContent(supportsVision: false);
    expect(payload['role'], 'user');
    expect((payload['parts'] as List).single['text'], contains('notes.png'));
    expect(
      (payload['parts'] as List).single['text'],
      contains('[Image attached: notes.png]'),
    );
  });

  test('openai compatible sse parser ignores reasoning metadata and keeps answer text', () async {
    final events = [
      'data: {"choices":[{"delta":{"reasoning_content":"First thought. "}}]}\n',
      'data: {"choices":[{"delta":{"reasoning_content":"Second thought. "}}]}\n',
      'data: {"choices":[{"delta":{"content":"Final answer."}}]}\n',
      'data: [DONE]\n',
    ];

    final output = await parseOpenAiCompatibleSse(
      Stream<List<int>>.fromIterable(
        events.map((event) => event.codeUnits),
      ),
    ).toList();

    expect(output.join(), 'Final answer.');
  });

  test('openai compatible sse parser drops reasoning-only responses', () async {
    final events = [
      'data: {"choices":[{"delta":{"reasoning":"Hidden chain."}}]}\n',
      'data: {"choices":[{"finish_reason":"stop"}]}\n',
    ];

    final output = await parseOpenAiCompatibleSse(
      Stream<List<int>>.fromIterable(
        events.map((event) => event.codeUnits),
      ),
    ).toList();

    expect(output, isEmpty);
  });

  test('openai compatible sse parser skips typed thinking chunks', () async {
    final events = [
      'data: {"choices":[{"delta":{"content":[{"type":"thinking","thinking":[{"type":"text","text":"Plan it. "}]}]}}]}\n',
      'data: {"choices":[{"delta":{"content":[{"type":"text","text":"Done."}]}}]}\n',
      'data: [DONE]\n',
    ];

    final output = await parseOpenAiCompatibleSse(
      Stream<List<int>>.fromIterable(
        events.map((event) => event.codeUnits),
      ),
    ).toList();

    expect(output.join(), 'Done.');
  });

  test('gemini datasource splits very large answer parts into smaller chunks',
      () async {
    final longAnswer = List.generate(
      30,
      (index) =>
          'Paragraph ${index + 1}. This is a long Gemini response sentence for smooth streaming.',
    ).join(' ');

    final sseBody = '${[
      'data: ${jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'thought': true, 'text': 'I should write a long answer.'},
                  ],
                },
              },
            ],
          })}',
      'data: ${jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': longAnswer},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          })}',
    ].join('\n')}\n';

    final client = MockClient((request) async {
      return http.Response(
        sseBody,
        200,
        headers: const {'content-type': 'text/event-stream'},
      );
    });
    final dataSource = GeminiRemoteDataSource(client: client);

    final stream = dataSource.streamChatCompletion(
      apiKey: 'g-key',
      model: const ModelOption(
        name: 'Gemini 2.5 Flash',
        id: 'gemini-2.5-flash',
        blurb: 'fast',
        provider: AiProviderType.gemini,
      ),
      systemPrompt: 'Be helpful.',
      history: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'Write a long story',
          createdAt: DateTime(2026),
        ),
      ],
    );

    final chunks = await stream.toList();

    expect(chunks.join(), isNot(contains('I should write a long answer.')));
    expect(chunks.join(), contains(longAnswer));
    expect(chunks.where((chunk) => chunk.contains('Paragraph')).length, greaterThan(2));
  });
}

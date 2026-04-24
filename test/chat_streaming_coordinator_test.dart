import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_streaming_coordinator.dart';

void main() {
  ChatStreamingRequest buildRequest() {
    return ChatStreamingRequest(
      providerKeys: const ProviderKeys(openRouter: 'key'),
      customProviders: const <CustomProviderConfig>[],
      model: const ModelOption(
        name: 'Test Model',
        id: 'test-model',
        blurb: 'test',
      ),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.openRouter],
      systemPrompt: 'hello',
      history: [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'hi',
          createdAt: DateTime(2024, 1, 1),
        ),
      ],
    );
  }

  test('start streams, animates, and emits final assistant reply', () async {
    final coordinator = ChatStreamingCoordinator(
      streamFactory: ({
        required providerKeys,
        required customProviders,
        required model,
        required routingMode,
        required enabledProviders,
        required systemPrompt,
        required history,
        onProviderSelected,
        onProviderNotice,
      }) {
        onProviderSelected?.call(AiProviderType.openRouter, model);
        onProviderNotice?.call('Using OpenRouter');
        return Stream<String>.fromIterable(const ['Hello', ' world']);
      },
    );
    addTearDown(coordinator.dispose);

    final replies = <String>[];
    final notices = <String>[];
    final providerSelections = <String>[];

    await coordinator.start(
      request: buildRequest(),
      onAssistantReply: (reply) async => replies.add(reply),
      onSettled: () async {},
      onErrorMessage: fail,
      onStateChanged: () {},
      onProviderSelected: (provider, model) {
        providerSelections.add('${provider.name}:${model.id}');
      },
      onProviderNotice: notices.add,
    );

    expect(replies, ['Hello world']);
    expect(notices, ['Using OpenRouter']);
    expect(providerSelections, ['openRouter:test-model']);
    expect(coordinator.isStreaming, isFalse);
    expect(coordinator.isTypingAssistant, isFalse);
    expect(coordinator.streamingDraft, isEmpty);
  });

  test('stop finalizes partial reply with stopped marker and clears draft',
      () async {
    final controller = StreamController<String>();
    var controllerClosed = false;
    final coordinator = ChatStreamingCoordinator(
      streamFactory: ({
        required providerKeys,
        required customProviders,
        required model,
        required routingMode,
        required enabledProviders,
        required systemPrompt,
        required history,
        onProviderSelected,
        onProviderNotice,
      }) {
        return controller.stream;
      },
    );
    addTearDown(() async {
      if (!controllerClosed) {
        await controller.close();
      }
      coordinator.dispose();
    });

    final replies = <String>[];
    final startFuture = coordinator.start(
      request: buildRequest(),
      onAssistantReply: (reply) async => replies.add(reply),
      onSettled: () async {},
      onErrorMessage: fail,
      onStateChanged: () {},
    );

    controller.add('Partial');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await coordinator.stop(
      onAssistantReply: (reply) async => replies.add(reply),
      onSettled: () async {},
      onStateChanged: () {},
    );
    await controller.close();
    controllerClosed = true;
    await startFuture;

    expect(replies, ['Partial\n\n*(stopped)*']);
    expect(coordinator.isStreaming, isFalse);
    expect(coordinator.streamingDraft, isEmpty);
  });

  test('stop clears waiting indicator before settling when no draft exists',
      () async {
    final controller = StreamController<String>();
    var controllerClosed = false;
    final coordinator = ChatStreamingCoordinator(
      streamFactory: ({
        required providerKeys,
        required customProviders,
        required model,
        required routingMode,
        required enabledProviders,
        required systemPrompt,
        required history,
        onProviderSelected,
        onProviderNotice,
      }) {
        return controller.stream;
      },
    );
    addTearDown(() async {
      if (!controllerClosed) {
        await controller.close();
      }
      coordinator.dispose();
    });

    final events = <String>[];
    coordinator.prepareForStreaming();

    final startFuture = coordinator.start(
      request: buildRequest(),
      onAssistantReply: (_) async {},
      onSettled: () async => events.add('settled'),
      onErrorMessage: fail,
      onStateChanged: () {
        events.add(
          'state:${coordinator.isWaitingForAssistant}:${coordinator.isTypingAssistant}',
        );
      },
    );

    await coordinator.stop(
      onAssistantReply: (_) async {},
      onSettled: () async => events.add('stop-settled'),
      onStateChanged: () {
        events.add(
          'stop-state:${coordinator.isWaitingForAssistant}:${coordinator.isTypingAssistant}',
        );
      },
    );
    await controller.close();
    controllerClosed = true;
    await startFuture;

    expect(events.first, 'stop-state:false:false');
    expect(events, contains('stop-settled'));
  });

  test('large gemini-style answer chunk reveals progressively after thinking',
      () async {
    final controller = StreamController<String>();
    var controllerClosed = false;
    final coordinator = ChatStreamingCoordinator(
      streamFactory: ({
        required providerKeys,
        required customProviders,
        required model,
        required routingMode,
        required enabledProviders,
        required systemPrompt,
        required history,
        onProviderSelected,
        onProviderNotice,
      }) {
        return controller.stream;
      },
      revealTick: const Duration(milliseconds: 8),
    );
    addTearDown(() async {
      if (!controllerClosed) {
        await controller.close();
      }
      coordinator.dispose();
    });

    final longAnswer = List.generate(
      60,
      (index) => 'Sentence ${index + 1}. This is a very long Gemini answer.',
    ).join(' ');
    final request = ChatStreamingRequest(
      providerKeys: const ProviderKeys(gemini: 'g-key'),
      customProviders: const <CustomProviderConfig>[],
      model: const ModelOption(
        name: 'Gemini 2.5 Flash',
        id: 'gemini-2.5-flash',
        blurb: 'fast',
        provider: AiProviderType.gemini,
      ),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.gemini],
      systemPrompt: 'hello',
      history: [
        ChatMessage(
          id: '1',
          role: 'user',
          content: 'Write a long story',
          createdAt: DateTime(2024, 1, 1),
        ),
      ],
    );

    coordinator.prepareForStreaming();
    final replies = <String>[];
    final startFuture = coordinator.start(
      request: request,
      onAssistantReply: (reply) async => replies.add(reply),
      onSettled: () async {},
      onErrorMessage: fail,
      onStateChanged: () {},
    );

    controller.add('<think>Plan the story first.</think>\n\n');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    controller.add(longAnswer);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(coordinator.isTypingAssistant, isTrue);
    expect(coordinator.streamingDraft, isNotEmpty);
    expect(coordinator.streamingDraft.length, lessThan(longAnswer.length));

    await controller.close();
    controllerClosed = true;
    await startFuture;

    expect(replies.single, contains('Sentence 60'));
  });
}

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_descriptors.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/core/services/app_controller.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_session_store.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_streaming_coordinator.dart';
import 'package:gidar_ai_flutter/src/data/remote/gemini_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/remote/zai_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/repository/chat_completion_repository.dart';
import 'package:gidar_ai_flutter/src/data/repository/settings_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'settings save persists and restored controller can route and stream a reply',
    () async {
      final secureStorage = _FakeSecureStorage();
      final zAiRemote = _FakeZaiRemoteDataSource(
        onStream: ({
          required apiKey,
          required model,
          required systemPrompt,
          required history,
        }) {
          expect(apiKey, 'z-key');
          expect(model.provider, AiProviderType.zAi);
          expect(
            systemPrompt,
            buildEffectiveSystemPrompt('Vision system prompt'),
          );
          expect(history.single.promptText, 'What is in this image?');
          expect(history.single.attachments, hasLength(1));
          expect(history.single.attachments.single.inlineDataBase64, 'abc123');
          return Stream<String>.fromIterable(const ['Vision', ' reply']);
        },
      );

      final initialController = _buildController(
        secureStorage: secureStorage,
        repository: ChatCompletionRepository(
          zaiRemoteDataSource: zAiRemote,
        ),
      );
      addTearDown(initialController.dispose);

      await initialController.initialize();
      final selectedModel = SettingsRepository.builtInModels.firstWhere(
        (model) => model.provider == AiProviderType.zAi,
      );

      await initialController.saveSettings(
        apiKey: '',
        systemPrompt: 'Vision system prompt',
        model: selectedModel,
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.system,
        dynamicThemeEnabled: true,
        appFontPreset: AppFontPreset.dmSans,
        chatFontPreset: AppFontPreset.kalam,
        chatColorMode: ChatColorMode.colorful,
        providerKeys: const ProviderKeys(
          zAi: 'z-key',
        ),
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.zAi],
        uiDensityMode: UiDensityMode.compact,
      );

      final restoredController = _buildController(
        secureStorage: secureStorage,
        repository: ChatCompletionRepository(
          zaiRemoteDataSource: zAiRemote,
        ),
      );
      addTearDown(restoredController.dispose);

      await restoredController.initialize();

      expect(restoredController.providerKeys.zAi, 'z-key');
      expect(restoredController.appearanceMode, AppAppearanceMode.system);
      expect(restoredController.dynamicThemeEnabled, isTrue);
      expect(restoredController.appFontPreset, AppFontPreset.dmSans);
      expect(restoredController.chatFontPreset, AppFontPreset.kalam);
      expect(restoredController.chatColorMode, ChatColorMode.colorful);
      expect(restoredController.routingMode, ChatRoutingMode.directModel);
      expect(restoredController.selectedModel?.id, selectedModel.id);
      expect(restoredController.hasReachableProviderKeyForCurrentMode, isTrue);

      await restoredController.startChat(
        'What is in this image?',
        displayPrompt: 'What is in this image?\n\nAttachments:\n- photo.png',
        attachments: const [
          ChatAttachment(
            name: 'photo.png',
            type: ComposerAttachmentType.image,
            mediaType: 'image/png',
            inlineDataBase64: 'abc123',
          ),
        ],
      );

      final session = restoredController.selectedSession;
      expect(session, isNotNull);
      expect(session!.messages, hasLength(2));
      expect(session.messages.first.content, contains('Attachments:'));
      expect(session.messages.first.attachments.single.name, 'photo.png');
      expect(session.messages.last.role, 'assistant');
      expect(session.messages.last.content, 'Vision reply');
      expect(restoredController.activeProvider, AiProviderType.zAi);
      expect(restoredController.activeProviderLabel, contains('Z.ai'));
    },
  );

  test(
    'preloaded preferences are available before background chat hydration finishes',
    () async {
      final secureStorage = _FakeSecureStorage();
      final delayedChats = Completer<List<ChatSession>>();
      final cachedSessions = [
        ChatSession(
          id: 'cached-1',
          title: 'Cached chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          messages: const [],
        ),
      ];
      final initialSettings = AppSettings(
        apiKey: '',
        providerKeys: const ProviderKeys(gemini: 'g-key'),
        customProvider: const CustomProviderConfig(),
        selectedModel: SettingsRepository.builtInModels.firstWhere(
          (model) => model.provider == AiProviderType.gemini,
        ),
        systemPrompt: 'Boot fast.',
        themeMode: AppThemeMode.pureLight,
        appearanceMode: AppAppearanceMode.light,
        dynamicThemeEnabled: false,
        customModels: const [],
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.gemini],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.manrope,
        chatFontPreset: AppFontPreset.hind,
        chatColorMode: ChatColorMode.theme,
      );

      final controller = AppController(
        initialSettings: initialSettings,
        initialSharedPreferences: await SharedPreferences.getInstance(),
        initialSidebarSessions: cachedSessions,
        packageInfoLoader: () async => PackageInfo(
          appName: 'Gidar AI',
          packageName: 'com.example.gidar',
          version: '1.0.0',
          buildNumber: '1',
          buildSignature: '',
          installerStore: null,
        ),
        settingsRepositoryFactory: (prefs) =>
            SettingsRepository(prefs, secureStorage: secureStorage),
        chatSessionStoreFactory: () => ChatSessionStore(
          loadAllChats: () => delayedChats.future,
          saveChat: (_) async {},
          deleteChat: (_) async {},
          clearAllChats: () async {},
        ),
        chatStreamingCoordinatorFactory: (streamFactory) =>
            ChatStreamingCoordinator(
          streamFactory: streamFactory,
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.themeMode, AppThemeMode.pureLight);
      expect(controller.appearanceMode, AppAppearanceMode.light);
      expect(controller.appFontPreset, AppFontPreset.manrope);
      expect(controller.chatFontPreset, AppFontPreset.hind);
      expect(controller.sidebarSessions.single.title, 'Cached chat');
      expect(controller.isReady, isTrue);

      await controller.initializeForApp();
      await Future<void>.delayed(Duration.zero);

      expect(controller.isHydratingChats, isTrue);
      expect(controller.hasHydratedChats, isFalse);
      expect(controller.sidebarSessions.single.title, 'Cached chat');

      delayedChats.complete([
        ChatSession(
          id: 'real-1',
          title: 'Real hydrated chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 3),
          messages: const [],
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.isHydratingChats, isFalse);
      expect(controller.hasHydratedChats, isTrue);
      expect(controller.sidebarSessions.single.title, 'Real hydrated chat');
    },
  );

  test(
      'pinned and starred metadata survives hydration and keeps pinned chats on top',
      () async {
    final secureStorage = _FakeSecureStorage();
    final controller = AppController(
      initialSettings: AppSettings(
        apiKey: '',
        providerKeys: const ProviderKeys(gemini: 'g-key'),
        customProvider: const CustomProviderConfig(),
        selectedModel: SettingsRepository.builtInModels.firstWhere(
          (model) => model.provider == AiProviderType.gemini,
        ),
        systemPrompt: 'Be helpful.',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.dark,
        dynamicThemeEnabled: false,
        customModels: const [],
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.gemini],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.inter,
        chatColorMode: ChatColorMode.theme,
      ),
      initialSharedPreferences: await SharedPreferences.getInstance(),
      initialSidebarSessions: [
        ChatSession(
          id: 'chat-1',
          title: 'Pinned cached chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          messages: const [],
          isPinned: true,
        ),
        ChatSession(
          id: 'chat-2',
          title: 'Starred cached chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 3),
          messages: const [],
          isStarred: true,
        ),
      ],
      packageInfoLoader: () async => PackageInfo(
        appName: 'Gidar AI',
        packageName: 'com.example.gidar',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      ),
      settingsRepositoryFactory: (prefs) =>
          SettingsRepository(prefs, secureStorage: secureStorage),
      chatSessionStoreFactory: () => ChatSessionStore(
        loadAllChats: () async => [
          ChatSession(
            id: 'chat-1',
            title: 'Pinned hydrated chat',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 2),
            messages: const [],
          ),
          ChatSession(
            id: 'chat-2',
            title: 'Starred hydrated chat',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 3),
            messages: const [],
          ),
        ],
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      ),
      chatStreamingCoordinatorFactory: (streamFactory) =>
          ChatStreamingCoordinator(
        streamFactory: streamFactory,
      ),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.sidebarSessions.first.id, 'chat-1');
    expect(controller.sidebarSessions.first.isPinned, isTrue);
    expect(
      controller.sidebarSessions
          .firstWhere((session) => session.id == 'chat-2')
          .isStarred,
      isTrue,
    );

    await controller.toggleSessionPinned('chat-2');

    expect(
      controller.sidebarSessions.take(2).every((session) => session.isPinned),
      isTrue,
    );
  });

  test(
      'editing last message replaces the last turn before requesting a new reply',
      () async {
    final requests = <List<ChatMessage>>[];
    final controller = _buildController(
      secureStorage: _FakeSecureStorage(),
      repository: ChatCompletionRepository(
        geminiRemoteDataSource: _FakeGeminiRemoteDataSource(
          onStream: ({
            required apiKey,
            required model,
            required systemPrompt,
            required history,
          }) {
            requests.add(List<ChatMessage>.from(history));
            final latestPrompt = history.last.promptText;
            if (latestPrompt == 'Apple kya hai?') {
              return Stream<String>.fromIterable(
                  const ['Apple ek phal hai...']);
            }
            if (latestPrompt == 'Apple company kya hai?') {
              return Stream<String>.fromIterable(
                const ['Apple ek tech company hai...'],
              );
            }
            return const Stream<String>.empty();
          },
        ),
      ),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final geminiModel = SettingsRepository.builtInModels.firstWhere(
      (model) => model.provider == AiProviderType.gemini,
    );
    await controller.saveSettings(
      apiKey: '',
      systemPrompt: 'Be helpful.',
      model: geminiModel,
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      providerKeys: const ProviderKeys(gemini: 'g-key'),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.gemini],
      uiDensityMode: UiDensityMode.compact,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.inter,
    );

    await controller.startChat('Apple kya hai?');
    expect(controller.selectedSession!.messages, hasLength(2));
    expect(controller.selectedSession!.messages.last.content,
        'Apple ek phal hai...');

    final messageId = controller.selectedSession!.messages.first.id;
    final draft = controller.prepareLastUserMessageEdit(messageId);
    expect(draft, 'Apple kya hai?');
    expect(controller.selectedSession!.messages, hasLength(2));

    await controller.sendEditedMessage(
      messageId,
      'Apple company kya hai?',
      displayPrompt: 'Apple company kya hai?',
    );

    final messages = controller.selectedSession!.messages;
    expect(messages, hasLength(2));
    expect(messages.first.role, 'user');
    expect(messages.first.content, 'Apple company kya hai?');
    expect(messages.last.role, 'assistant');
    expect(messages.last.content, 'Apple ek tech company hai...');

    expect(requests, hasLength(2));
    expect(requests.last, hasLength(1));
    expect(requests.last.single.role, 'user');
    expect(requests.last.single.promptText, 'Apple company kya hai?');
  });

  test(
      'streaming reply stays attached to its original session after switching chats',
      () async {
    final secondReplyController = StreamController<String>();
    final controller = _buildController(
      secureStorage: _FakeSecureStorage(),
      repository: ChatCompletionRepository(
        geminiRemoteDataSource: _FakeGeminiRemoteDataSource(
          onStream: ({
            required apiKey,
            required model,
            required systemPrompt,
            required history,
          }) {
            final latestPrompt = history.last.promptText;
            if (latestPrompt == 'First chat') {
              return Stream<String>.fromIterable(const ['First reply']);
            }
            if (latestPrompt == 'Second chat') {
              return secondReplyController.stream;
            }
            return const Stream<String>.empty();
          },
        ),
      ),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final geminiModel = SettingsRepository.builtInModels.firstWhere(
      (model) => model.provider == AiProviderType.gemini,
    );
    await controller.saveSettings(
      apiKey: '',
      systemPrompt: 'Be helpful.',
      model: geminiModel,
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      providerKeys: const ProviderKeys(gemini: 'g-key'),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.gemini],
      uiDensityMode: UiDensityMode.compact,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.inter,
      chatColorMode: ChatColorMode.theme,
    );

    await controller.startChat('First chat');
    final firstSession = controller.selectedSession!;

    final pendingSecondChat = controller.startChat('Second chat');
    for (var index = 0; index < 20; index++) {
      if (controller.isStreaming &&
          controller.selectedSession?.title == 'Second chat') {
        break;
      }
      await Future<void>.delayed(Duration.zero);
    }

    final secondSessionId = controller.selectedSession?.id;
    expect(controller.isStreaming, isTrue);
    expect(secondSessionId, isNotNull);
    expect(secondSessionId, isNot(firstSession.id));
    expect(controller.streamingSessionId, secondSessionId);

    controller.selectSession(firstSession);
    expect(controller.selectedSession?.id, firstSession.id);

    secondReplyController
      ..add('Second')
      ..add(' reply');
    await secondReplyController.close();
    await pendingSecondChat;

    final refreshedFirstSession = controller.sessions.firstWhere(
      (session) => session.id == firstSession.id,
    );
    final refreshedSecondSession = controller.sessions.firstWhere(
      (session) => session.id == secondSessionId,
    );

    expect(refreshedFirstSession.messages, hasLength(2));
    expect(refreshedFirstSession.messages.last.content, 'First reply');
    expect(refreshedSecondSession.messages, hasLength(2));
    expect(refreshedSecondSession.messages.last.content, 'Second reply');
    expect(controller.selectedSession?.id, firstSession.id);
    expect(controller.streamingSessionId, isNull);
  });

  test('custom prompt persists and clearing falls back to default', () async {
    final controller = _buildController(
      secureStorage: _FakeSecureStorage(),
      repository: ChatCompletionRepository(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    final selectedModel = SettingsRepository.builtInModels.first;

    const customPrompt =
        'You are a sharp assistant. Use short Hinglish explanations with clear steps.';

    await controller.saveSettings(
      apiKey: '',
      systemPrompt: customPrompt,
      model: selectedModel,
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      providerKeys: const ProviderKeys(),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.openRouter],
      uiDensityMode: UiDensityMode.compact,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.inter,
      chatColorMode: ChatColorMode.theme,
    );

    expect(controller.systemPrompt, customPrompt.trim());

    await controller.saveSettings(
      apiKey: '',
      systemPrompt: '   ',
      model: selectedModel,
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      providerKeys: const ProviderKeys(),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.openRouter],
      uiDensityMode: UiDensityMode.compact,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.inter,
      chatColorMode: ChatColorMode.theme,
    );

    expect(controller.systemPrompt, defaultSystemPrompt);
  });
}

AppController _buildController({
  required FlutterSecureStorage secureStorage,
  required ChatCompletionRepository repository,
}) {
  return AppController(
    chatCompletionRepository: repository,
    packageInfoLoader: () async => PackageInfo(
      appName: 'Gidar AI',
      packageName: 'com.example.gidar',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    ),
    sharedPreferencesLoader: SharedPreferences.getInstance,
    settingsRepositoryFactory: (prefs) =>
        SettingsRepository(prefs, secureStorage: secureStorage),
    chatSessionStoreFactory: _buildInMemoryChatStore,
    chatStreamingCoordinatorFactory: (streamFactory) =>
        ChatStreamingCoordinator(
      streamFactory: streamFactory,
    ),
  );
}

ChatSessionStore _buildInMemoryChatStore() {
  final savedSessions = <String, ChatSession>{};
  return ChatSessionStore(
    loadAllChats: () async => savedSessions.values.toList(),
    saveChat: (session) async {
      savedSessions[session.id] = session;
    },
    deleteChat: (id) async {
      savedSessions.remove(id);
    },
    clearAllChats: () async {
      savedSessions.clear();
    },
  );
}

typedef _OnStream = Stream<String> Function({
  required String apiKey,
  required ModelOption model,
  required String systemPrompt,
  required List<ChatMessage> history,
});

class _FakeGeminiRemoteDataSource extends GeminiRemoteDataSource {
  _FakeGeminiRemoteDataSource({required _OnStream onStream})
      : _onStream = onStream;

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

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.clear();
  }
}

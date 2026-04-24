import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/local/app_database.dart';
import '../../data/remote/cerebras_remote_data_source.dart';
import '../../data/remote/custom_openai_remote_data_source.dart';
import '../../data/remote/gemini_remote_data_source.dart';
import '../../data/remote/groq_remote_data_source.dart';
import '../../data/remote/mistral_remote_data_source.dart';
import '../../data/remote/openrouter_remote_data_source.dart';
import '../../data/remote/sambanova_remote_data_source.dart';
import '../../data/remote/zai_remote_data_source.dart';
import '../../data/repository/chat_repository.dart';
import '../../data/repository/chat_completion_repository.dart';
import '../../data/repository/provider_router.dart';
import '../../data/repository/settings_repository.dart';
import '../../domain/usecases/stream_chat_completion_use_case.dart';
import '../models/app_descriptors.dart';
import '../models/app_preferences_state.dart';
import '../models/app_models.dart';
import 'chat_session_store.dart';
import 'chat_streaming_coordinator.dart';
import 'provider_health_store.dart';

typedef SharedPreferencesLoader = Future<SharedPreferences> Function();
typedef PackageInfoLoader = Future<PackageInfo> Function();
typedef SettingsRepositoryFactory = SettingsRepository Function(
  SharedPreferences prefs,
);
typedef ChatSessionStoreFactory = ChatSessionStore Function();
typedef ChatStreamingCoordinatorFactory = ChatStreamingCoordinator Function(
  ChatCompletionStreamFactory streamFactory,
);

const MethodChannel _appearanceChannel =
    MethodChannel('ai.gidar.app/appearance');

class AppController extends ChangeNotifier {
  AppController({
    ChatCompletionRepository? chatCompletionRepository,
    AppDatabase? database,
    ProviderRouter? providerRouter,
    ProviderHealthStore? providerHealthStore,
    AppSettings? initialSettings,
    SharedPreferences? initialSharedPreferences,
    List<ChatSession> initialSidebarSessions = const <ChatSession>[],
    bool markReadyFromInitialSettings = true,
    SharedPreferencesLoader? sharedPreferencesLoader,
    PackageInfoLoader? packageInfoLoader,
    SettingsRepositoryFactory? settingsRepositoryFactory,
    ChatSessionStoreFactory? chatSessionStoreFactory,
    ChatStreamingCoordinatorFactory? chatStreamingCoordinatorFactory,
  })  : _database = chatSessionStoreFactory == null
            ? (database ?? AppDatabase())
            : null,
        _chatCompletionRepository =
            chatCompletionRepository ?? ChatCompletionRepository(),
        _providerRouter = providerRouter ?? const ProviderRouter(),
        _providerHealthStore = providerHealthStore ?? ProviderHealthStore(),
        _sharedPreferencesLoader =
            sharedPreferencesLoader ?? SharedPreferences.getInstance,
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _initialSettings = initialSettings,
        _initialSharedPreferences = initialSharedPreferences,
        _markReadyFromInitialSettings = markReadyFromInitialSettings,
        _initialSidebarSessions = List<ChatSession>.unmodifiable(
          initialSidebarSessions,
        ),
        _settingsRepositoryFactory =
            settingsRepositoryFactory ?? ((prefs) => SettingsRepository(prefs)),
        _chatSessionStoreFactory = chatSessionStoreFactory,
        _chatStreamingCoordinatorFactory = chatStreamingCoordinatorFactory ??
            ((streamFactory) =>
                ChatStreamingCoordinator(streamFactory: streamFactory)) {
    if (_initialSettings != null) {
      final initialSettings = _initialSettings;
      models = List<ModelOption>.from(initialSettings.fetchedModels);
      _preferences = AppPreferencesState.fromStored(
        initialSettings,
        availableModels: models,
      );
      _chatCompletionRepository.updateCustomProviderConfig(
        _preferences.customProvider,
      );
      _selectedProvider = _normalizeSelectedProvider(
        initialSettings.selectedProvider,
        enabledProviders: _preferences.enabledProviders,
      );
      if (_markReadyFromInitialSettings) {
        _isReady = true;
      }
    }
    _cachedSidebarSessions = List<ChatSession>.from(_initialSidebarSessions);
  }

  final AppDatabase? _database;
  final ChatCompletionRepository _chatCompletionRepository;
  final ProviderRouter _providerRouter;
  final ProviderHealthStore _providerHealthStore;
  final SharedPreferencesLoader _sharedPreferencesLoader;
  final PackageInfoLoader _packageInfoLoader;
  final AppSettings? _initialSettings;
  final SharedPreferences? _initialSharedPreferences;
  final bool _markReadyFromInitialSettings;
  final List<ChatSession> _initialSidebarSessions;
  final SettingsRepositoryFactory _settingsRepositoryFactory;
  final ChatSessionStoreFactory? _chatSessionStoreFactory;
  final ChatStreamingCoordinatorFactory _chatStreamingCoordinatorFactory;

  ChatRepository? _chatRepository;
  ChatSessionStore _chatSessionStore = ChatSessionStore(
    loadAllChats: () async => <ChatSession>[],
    saveChat: (_) async {},
    deleteChat: (_) async {},
    clearAllChats: () async {},
  );
  ChatStreamingCoordinator _chatStreamingCoordinator = ChatStreamingCoordinator(
    streamFactory: _emptyChatCompletionStreamFactory,
  );
  late final SettingsRepository _settingsRepository;
  late final StreamChatCompletionUseCase _streamChatCompletionUseCase;
  SharedPreferences? _sharedPreferences;
  bool _hasSettingsRepository = false;

  List<ModelOption> models = <ModelOption>[];

  final List<String> suggestions = const [
    'Explain quantum computing in simple Hindi-English.',
    'Build a clean Flutter login screen with validation.',
    'Plan a 3-day Goa trip with budget and food spots.',
    'Summarize this text into crisp action items.',
  ];

  String _appVersion = '2.0.0';
  String _appBuildNumber = '1';
  AppPreferencesState _preferences = AppPreferencesState.initial();
  bool _isReady = false;
  bool _isHydratingChats = false;
  bool _hasHydratedChats = false;
  String? _errorMessage;
  String? _statusMessage;
  int _currentIndex = 0;
  AiProviderType? _activeProvider;
  String? _activeProviderModelName;
  String? _activeCustomProviderId;
  String? _activeStreamingSessionId;
  AiProviderType? _selectedProvider;
  String? _selectedCustomProviderId;
  Completer<void>? _requestLock;
  bool _dynamicThemeAvailable = false;
  List<ChatSession> _cachedSidebarSessions = <ChatSession>[];
  Map<String, double> _modelPickerScrollOffsets = <String, double>{};

  bool get isReady => _isReady;
  bool get isHydratingChats => _isHydratingChats;
  bool get hasHydratedChats => _hasHydratedChats;
  bool get isStreaming => _chatStreamingCoordinator.isStreaming;
  bool get isWaitingForAssistant =>
      _chatStreamingCoordinator.isWaitingForAssistant;
  bool get isTypingAssistant => _chatStreamingCoordinator.isTypingAssistant;
  String get streamingDraft => _chatStreamingCoordinator.streamingDraft;
  String get apiKey => _preferences.apiKey;
  String get appVersionLabel =>
      formatAppVersionLabel(_appVersion, _appBuildNumber);
  ProviderKeys get providerKeys => _preferences.providerKeys;
  CustomProviderConfig get customProvider => _preferences.customProvider;
  List<CustomProviderConfig> get customProviders =>
      List.unmodifiable(_preferences.customProviders);
  String get systemPrompt => _preferences.systemPrompt;
  AppThemeMode get themeMode => _preferences.themeMode;
  AppAppearanceMode get appearanceMode => _preferences.appearanceMode;
  bool get dynamicThemeEnabled => _preferences.dynamicThemeEnabled;
  bool get dynamicThemeAvailable => _dynamicThemeAvailable;
  ChatRoutingMode get routingMode => _preferences.routingMode;
  UiDensityMode get uiDensityMode => _preferences.uiDensityMode;
  AppFontPreset get appFontPreset => _preferences.appFontPreset;
  AppFontPreset get chatFontPreset => _preferences.chatFontPreset;
  ChatColorMode get chatColorMode => _preferences.chatColorMode;
  List<AiProviderType> get enabledProviders =>
      List.unmodifiable(_preferences.enabledProviders);
  ModelOption? get selectedModel => _preferences.selectedModel;
  List<ChatSession> get sessions => _chatSessionStore.sessions;
  List<ChatSession> get sidebarSessions => _hasHydratedChats
      ? _chatSessionStore.sessions
      : List.unmodifiable(_cachedSidebarSessions);
  bool get hasSidebarCache => _cachedSidebarSessions.isNotEmpty;
  ChatSession? get selectedSession => _chatSessionStore.selectedSession;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  int get currentIndex => _currentIndex;
  AiProviderType? get activeProvider => _activeProvider;
  String? get streamingSessionId => _activeStreamingSessionId;
  AiProviderType? get selectedProvider => _selectedProvider;
  String? get selectedCustomProviderId => _selectedCustomProviderId;
  bool get hasAnyEnabledProviderKey => _preferences.hasAnyEnabledProviderKey;
  String get selectedProviderLabel {
    final selectedModel = _preferences.selectedModel;
    if (selectedModel != null) {
      return _preferences.providerLabelForModel(selectedModel);
    }
    final provider = _selectedProvider;
    if (provider == null) return 'All Providers';
    if (provider == AiProviderType.custom) {
      final firstCustomProvider = _preferences.customProviders.isEmpty
          ? null
          : _preferences.customProviders.first;
      return _preferences
              .customProviderForId(_selectedCustomProviderId)
              ?.normalizedName ??
          firstCustomProvider?.normalizedName ??
          providerLabel(provider);
    }
    return providerLabel(provider);
  }

  double modelPickerScrollOffsetFor(
    AiProviderType? provider, {
    String? customProviderId,
  }) {
    return _modelPickerScrollOffsets[_modelPickerScrollOffsetKey(
          provider,
          customProviderId: customProviderId,
        )] ??
        0;
  }

  bool get hasReachableProviderKeyForCurrentMode {
    return _preferences.hasReachableProviderKey(_providerRouter);
  }

  String get activeProviderLabel {
    final provider = _activeProvider;
    final modelName = _activeProviderModelName;
    if (provider == null || modelName == null || modelName.isEmpty) {
      return selectedModel?.name ?? 'No model selected';
    }
    final label = provider == AiProviderType.custom
        ? (_preferences
                .customProviderForId(_activeCustomProviderId)
                ?.normalizedName ??
            providerLabel(provider))
        : providerLabel(provider);
    return '$label • $modelName';
  }

  ProviderCheckStatus providerCheckFor(AiProviderType provider) {
    return _providerHealthStore.statusFor(provider);
  }

  bool hasKeyForProvider(AiProviderType provider) {
    if (provider == AiProviderType.custom) {
      return _preferences.customProviders.any(
        (customProvider) => customProvider.enabled && customProvider.hasApiKey,
      );
    }
    return _preferences.providerKeys.keyFor(provider).trim().isNotEmpty;
  }

  void dismissError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void dismissStatus() {
    if (_statusMessage == null) return;
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _initializeCore(awaitChatHydration: true);
  }

  Future<void> initializeForApp() async {
    await _initializeCore(awaitChatHydration: false);
  }

  Future<void> _initializeCore({required bool awaitChatHydration}) async {
    try {
      try {
        final packageInfo = await _packageInfoLoader();
        _appVersion = packageInfo.version;
        _appBuildNumber = packageInfo.buildNumber;
      } catch (_) {
        // Keep pubspec-aligned fallback values when platform package info isn't available.
      }

      final prefs = _sharedPreferences ??
          _initialSharedPreferences ??
          await _sharedPreferencesLoader();
      _sharedPreferences = prefs;
      _settingsRepository = _settingsRepositoryFactory(prefs);
      _hasSettingsRepository = true;
      _cachedSidebarSessions = _cachedSidebarSessions.isNotEmpty
          ? List<ChatSession>.from(_cachedSidebarSessions)
          : _settingsRepository.loadSidebarCache();
      _modelPickerScrollOffsets =
          _settingsRepository.loadModelPickerScrollOffsets();
      if (_chatSessionStoreFactory case final factory?) {
        _chatSessionStore = factory();
      } else {
        _chatRepository = ChatRepository(_database!);
        _chatSessionStore = ChatSessionStore(
          loadAllChats: () => _chatRepository!.loadAllChats().timeout(
                const Duration(seconds: 5),
                onTimeout: () => <ChatSession>[],
              ),
          saveChat: _chatRepository!.saveChat,
          deleteChat: _chatRepository!.deleteChat,
          clearAllChats: _chatRepository!.clearAll,
        );
      }
      _streamChatCompletionUseCase =
          StreamChatCompletionUseCase(_chatCompletionRepository);
      _chatStreamingCoordinator.dispose();
      _chatStreamingCoordinator = _chatStreamingCoordinatorFactory(
        _streamChatCompletionUseCase.call,
      );

      final settings = _initialSettings ??
          await _settingsRepository.loadSettings().timeout(
                const Duration(seconds: 5),
              );
      models = List<ModelOption>.from(settings.fetchedModels);
      _preferences = AppPreferencesState.fromStored(
        settings,
        availableModels: models,
      );
      _chatCompletionRepository.updateCustomProviderConfig(
        _preferences.customProvider,
      );
      _selectedProvider = _normalizeSelectedProvider(
        settings.selectedProvider,
        enabledProviders: _preferences.enabledProviders,
      );
      _selectedCustomProviderId = _normalizeSelectedCustomProviderId(
        _selectedProvider,
        preferredCustomProviderId: _preferences.selectedModel?.customProviderId,
      );
      _isReady = true;
      notifyListeners();
      if (awaitChatHydration) {
        await _hydrateChats();
      } else {
        unawaited(_hydrateChats());
      }
    } catch (error) {
      _errorMessage =
          'Startup recovery mode: saved data could not be fully loaded.';
      models = <ModelOption>[];
      _preferences = AppPreferencesState.initial();
      _chatCompletionRepository.updateCustomProviderConfig(
        _preferences.customProvider,
      );
      _selectedCustomProviderId = null;
      _chatSessionStore = ChatSessionStore(
        loadAllChats: () async => <ChatSession>[],
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      )..reset();
      _cachedSidebarSessions = const <ChatSession>[];
      _hasHydratedChats = true;
    } finally {
      _isReady = true;
      notifyListeners();
    }
  }

  void setTab(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void selectProvider(
    AiProviderType? provider, {
    String? customProviderId,
  }) {
    _selectedProvider = provider;
    _selectedCustomProviderId = _normalizeSelectedCustomProviderId(
      provider,
      preferredCustomProviderId: customProviderId,
    );
    if (_hasSettingsRepository) {
      unawaited(_settingsRepository.saveSelectedProvider(provider));
    }
    notifyListeners();
  }

  Future<void> saveModelPickerScrollOffset(
    AiProviderType? provider,
    double offset, {
    String? customProviderId,
  }) async {
    final normalized = offset < 0 ? 0.0 : offset;
    final key = _modelPickerScrollOffsetKey(
      provider,
      customProviderId: customProviderId,
    );
    final previous = _modelPickerScrollOffsets[key];
    if (previous != null && (previous - normalized).abs() < 1) return;
    _modelPickerScrollOffsets = <String, double>{
      ..._modelPickerScrollOffsets,
      key: normalized,
    };
    if (_hasSettingsRepository) {
      await _settingsRepository
          .saveModelPickerScrollOffsets(_modelPickerScrollOffsets);
    }
  }

  void selectSession(ChatSession session) {
    _chatSessionStore.selectSession(session);
    _currentIndex = 1;
    _errorMessage = null;
    notifyListeners();
  }

  List<ChatSession> filteredSessions(String query) {
    return _chatSessionStore.filteredSessions(query);
  }

  List<ChatSession> filteredSidebarSessions(String query) {
    final source = sidebarSessions;
    if (query.trim().isEmpty) return source;
    final normalized = query.trim().toLowerCase();
    return source.where((session) {
      final haystack = '${session.title} ${session.preview}'.toLowerCase();
      return haystack.contains(normalized);
    }).toList();
  }

  Future<void> saveSettings({
    required String apiKey,
    required String systemPrompt,
    required ModelOption? model,
    required AppThemeMode themeMode,
    AppAppearanceMode? appearanceMode,
    bool? dynamicThemeEnabled,
    ProviderKeys? providerKeys,
    CustomProviderConfig? customProvider,
    List<CustomProviderConfig>? customProviders,
    ChatRoutingMode? routingMode,
    List<AiProviderType>? enabledProviders,
    UiDensityMode? uiDensityMode,
    AppFontPreset? appFontPreset,
    AppFontPreset? chatFontPreset,
    ChatColorMode? chatColorMode,
  }) async {
    final previousCustomProviders = _preferences.customProviders;
    final nextCustomProviders = customProviders ??
        (customProvider != null
            ? (customProvider.hasAnyData ? [customProvider] : const [])
            : previousCustomProviders);
    var nextModel = model;
    models = _reconcileCustomModels(
      models,
      previousCustomProviders: previousCustomProviders,
      nextCustomProviders: nextCustomProviders,
    );
    if (nextModel?.provider == AiProviderType.custom &&
        !models
            .any((candidate) => candidate.sameSelectionIdentity(nextModel))) {
      nextModel = null;
    }
    if (nextModel != null &&
        !models
            .any((candidate) => candidate.sameSelectionIdentity(nextModel))) {
      models = [...models, nextModel];
    }
    final effectiveEnabledProviders = _withCustomProviderEnabledState(
      enabledProviders ?? _preferences.enabledProviders,
      nextCustomProviders,
    );
    _selectedProvider = _normalizeSelectedProvider(
      _selectedProvider,
      enabledProviders: effectiveEnabledProviders,
    );
    _preferences = _preferences.update(
      apiKey: apiKey,
      systemPrompt: systemPrompt,
      model: nextModel,
      themeMode: themeMode,
      appearanceMode: appearanceMode,
      dynamicThemeEnabled: dynamicThemeEnabled,
      providerKeys: providerKeys,
      customProvider:
          nextCustomProviders.isNotEmpty ? nextCustomProviders.first : null,
      customProviders: nextCustomProviders,
      routingMode: routingMode,
      enabledProviders: effectiveEnabledProviders,
      uiDensityMode: uiDensityMode,
      appFontPreset: appFontPreset,
      chatFontPreset: chatFontPreset,
      chatColorMode: chatColorMode,
    );
    _selectedCustomProviderId = _normalizeSelectedCustomProviderId(
      _selectedProvider,
      preferredCustomProviderId: nextModel?.customProviderId,
    );
    _chatCompletionRepository.updateCustomProviderConfig(
      _preferences.customProvider,
    );
    _errorMessage = null;
    await _settingsRepository.saveSettings(
      apiKey: _preferences.apiKey,
      selectedModel: _preferences.selectedModel,
      systemPrompt: _preferences.systemPrompt,
      themeMode: _preferences.themeMode,
      appearanceMode: _preferences.appearanceMode,
      dynamicThemeEnabled: _preferences.dynamicThemeEnabled,
      fetchedModels: models,
      providerKeys: _preferences.providerKeys,
      customProvider: _preferences.customProvider,
      customProviders: _preferences.customProviders,
      routingMode: _preferences.routingMode,
      enabledProviders: _preferences.enabledProviders,
      uiDensityMode: _preferences.uiDensityMode,
      appFontPreset: _preferences.appFontPreset,
      chatFontPreset: _preferences.chatFontPreset,
      chatColorMode: _preferences.chatColorMode,
      selectedProvider: _selectedProvider,
    );
    await _syncNativeLaunchTheme();
    notifyListeners();
  }

  void setDynamicThemeAvailability(bool available) {
    if (_dynamicThemeAvailable == available) return;
    _dynamicThemeAvailable = available;
    notifyListeners();
  }

  Future<bool> _acquireRequestLock() async {
    if (_requestLock != null && !_requestLock!.isCompleted) {
      return false;
    }
    _requestLock = Completer<void>();
    return true;
  }

  void _releaseRequestLock() {
    final lock = _requestLock;
    if (lock != null && !lock.isCompleted) {
      lock.complete();
    }
    _requestLock = null;
  }

  Future<ChatSession> startChat(
    String firstPrompt, {
    String? displayPrompt,
    List<ChatAttachment> attachments = const [],
  }) async {
    final prompt = firstPrompt.trim();
    if (prompt.isEmpty) {
      throw Exception('Message cannot be empty.');
    }
    if (_preferences.selectedModel == null) {
      _errorMessage = 'Fetch and select a model before sending a message.';
      notifyListeners();
      throw Exception('No model selected.');
    }
    if (isStreaming) return _chatSessionStore.selectedSession!;
    if (!await _acquireRequestLock()) {
      return _chatSessionStore.selectedSession!;
    }

    try {
      // Set typing state, then start session, then notify ONCE
      // so user message + assistant placeholder appear together.
      _chatStreamingCoordinator.prepareForStreaming();

      final session = await _chatSessionStore.startSession(
        prompt,
        displayContent: displayPrompt,
        attachments: attachments,
      );
      _syncSidebarCacheFromSessions();
      _currentIndex = 1;
      notifyListeners();
      await _requestAssistantReply(session, session.messages);
      return _chatSessionStore.sessionForId(session.id) ?? session;
    } finally {
      _releaseRequestLock();
    }
  }

  Future<void> sendMessage(
    String input, {
    String? displayPrompt,
    List<ChatAttachment> attachments = const [],
  }) async {
    final text = input.trim();
    if (text.isEmpty) return;
    if (_preferences.selectedModel == null) {
      _errorMessage = 'Fetch and select a model before sending a message.';
      notifyListeners();
      return;
    }

    if (selectedSession == null) {
      await startChat(
        text,
        displayPrompt: displayPrompt,
        attachments: attachments,
      );
      return;
    }

    if (isStreaming) return;
    if (!await _acquireRequestLock()) return;

    try {
      _errorMessage = null;
      final commandHandled = await _handleSlashCommand(text);
      if (commandHandled) return;

      // Set typing state, then add user message, then notify ONCE
      // so user message + assistant placeholder appear together.
      _chatStreamingCoordinator.prepareForStreaming();

      final updatedSession = _chatSessionStore.addUserMessage(
        text,
        displayContent: displayPrompt,
        attachments: attachments,
      );
      if (updatedSession == null) return;
      _syncSidebarCacheFromSessions();
      // Rebuild with user message + assistant placeholder together
      notifyListeners();
      await _requestAssistantReply(updatedSession, updatedSession.messages);
    } finally {
      _releaseRequestLock();
    }
  }

  Future<void> sendEditedMessage(
    String messageId,
    String input, {
    String? displayPrompt,
    List<ChatAttachment> attachments = const [],
  }) async {
    final text = input.trim();
    if (selectedSession == null || text.isEmpty || isStreaming) return;
    if (_preferences.selectedModel == null) {
      _errorMessage = 'Fetch and select a model before sending a message.';
      notifyListeners();
      return;
    }
    if (!await _acquireRequestLock()) return;

    try {
      _errorMessage = null;
      _chatStreamingCoordinator.prepareForStreaming();

      final updatedSession = _chatSessionStore.replaceLastUserMessageTurn(
        messageId,
        text,
        displayContent: displayPrompt,
        attachments: attachments,
      );
      if (updatedSession == null) {
        await _chatStreamingCoordinator.reset(
          onSettled: () async {},
          onStateChanged: () {},
        );
        return;
      }

      _syncSidebarCacheFromSessions();
      notifyListeners();
      await _requestAssistantReply(updatedSession, updatedSession.messages);
    } finally {
      _releaseRequestLock();
    }
  }

  Future<void> stopStreaming() async {
    final sessionId =
        _activeStreamingSessionId ?? _chatSessionStore.selectedSession?.id;
    await _chatStreamingCoordinator.stop(
      onAssistantReply: (reply) async {
        if (sessionId == null) return;
        await _chatSessionStore.appendAssistantMessageToSession(
          sessionId,
          reply,
        );
      },
      onSettled: () async {
        if (sessionId != null) {
          await _chatSessionStore.saveSessionById(sessionId);
        }
        if (_activeStreamingSessionId == sessionId) {
          _activeStreamingSessionId = null;
        }
        _syncSidebarCacheFromSessions();
      },
      onStateChanged: notifyListeners,
    );
    _releaseRequestLock();
  }

  Future<void> retryLastAssistantMessage() async {
    if (selectedSession == null || isStreaming) return;
    final retryPrompt = await _chatSessionStore.extractRetryPrompt();
    if (retryPrompt == null) return;
    await sendMessage(retryPrompt);
  }

  Future<void> setAssistantFeedback(
    String messageId,
    MessageFeedback feedback,
  ) async {
    if (selectedSession == null) return;
    await _chatSessionStore.setAssistantFeedback(messageId, feedback);
    notifyListeners();
  }

  String? prepareLastUserMessageEdit(String messageId) {
    if (selectedSession == null || isStreaming) return null;
    return _chatSessionStore.prepareLastUserMessageEdit(messageId);
  }

  Future<void> copyLastAssistantMessage() async {
    final session = selectedSession;
    if (session == null) return;
    for (final message in session.messages.reversed) {
      if (message.role == 'assistant' && message.content.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: message.content));
        return;
      }
    }
  }

  Future<void> clearCurrentChat() async {
    await _chatSessionStore.clearCurrentChat();
    _syncSidebarCacheFromSessions();
    if (selectedSession == null) {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _chatSessionStore.deleteSession(id);
    _syncSidebarCacheFromSessions();
    if (selectedSession == null) {
      _currentIndex = 0;
    }
    notifyListeners();
  }

  Future<void> toggleStarred() async {
    final session = selectedSession;
    if (session == null) return;
    final updated = session.copyWith(isStarred: !session.isStarred);
    _chatSessionStore.replaceSession(updated);
    _syncSidebarCacheFromSessions();
    notifyListeners();
  }

  Future<void> toggleSessionPinned(String id) async {
    final session = _chatSessionStore.sessionForId(id);
    if (session == null) return;
    final updated = session.copyWith(isPinned: !session.isPinned);
    _chatSessionStore.replaceSession(updated);
    _syncSidebarCacheFromSessions();
    notifyListeners();
  }

  Future<void> toggleSessionStarred(String id) async {
    final session = _chatSessionStore.sessionForId(id);
    if (session == null) return;
    final updated = session.copyWith(isStarred: !session.isStarred);
    _chatSessionStore.replaceSession(updated);
    _syncSidebarCacheFromSessions();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _errorMessage = null;
    _statusMessage = null;
    _activeProvider = null;
    _activeProviderModelName = null;
    _activeCustomProviderId = null;
    _activeStreamingSessionId = null;
    _providerHealthStore.clear();
    _releaseRequestLock();
    await _chatStreamingCoordinator.reset(
      onSettled: () async {},
      onStateChanged: notifyListeners,
    );
    await _chatSessionStore.clearAll();
    _cachedSidebarSessions = const <ChatSession>[];
    unawaited(_settingsRepository.clearSidebarCache());
    await _settingsRepository.clearAll();
    models = <ModelOption>[];
    _preferences = AppPreferencesState.initial();
    _chatCompletionRepository.updateCustomProviderConfig(
      _preferences.customProvider,
    );
    await _syncNativeLaunchTheme();
    _currentIndex = 0;
    notifyListeners();
  }

  Future<void> _syncNativeLaunchTheme() async {
    try {
      await _appearanceChannel.invokeMethod<void>('syncLaunchTheme');
    } catch (_) {
      // Native launch theme syncing is only relevant on Android.
    }
  }

  Future<bool> _handleSlashCommand(String text) async {
    switch (text.trim()) {
      case '/new':
        _currentIndex = 0;
        notifyListeners();
        return true;
      case '/clear':
        await clearCurrentChat();
        return true;
      case '/settings':
        _currentIndex = 2;
        notifyListeners();
        return true;
      case '/copy':
        await copyLastAssistantMessage();
        return true;
      case '/model':
        _errorMessage = 'Model picker is available in Settings for now.';
        notifyListeners();
        return true;
      case '/help':
        _errorMessage =
            'Available commands: /new /clear /settings /copy /model /help';
        notifyListeners();
        return true;
      case '/export':
        _statusMessage = 'Use the export action from the chat screen.';
        notifyListeners();
        return true;
      default:
        return false;
    }
  }

  Future<void> _requestAssistantReply(
    ChatSession session,
    List<ChatMessage> history,
  ) async {
    final selectedModel = _preferences.selectedModel;
    if (selectedModel == null) {
      _errorMessage = 'Fetch and select a model before sending a message.';
      notifyListeners();
      return;
    }
    _activeProvider = null;
    _activeProviderModelName = null;
    _activeCustomProviderId = null;
    _activeStreamingSessionId = session.id;
    final sessionId = session.id;
    await _chatStreamingCoordinator.start(
      request: ChatStreamingRequest(
        providerKeys: _preferences.providerKeys,
        customProviders: _preferences.customProviders,
        model: selectedModel,
        routingMode: _preferences.routingMode,
        enabledProviders: _preferences.enabledProviders,
        systemPrompt: _preferences.systemPrompt,
        history: history,
      ),
      onAssistantReply: (reply) =>
          _chatSessionStore.appendAssistantMessageToSession(sessionId, reply),
      onSettled: () async {
        await _chatSessionStore.saveSessionById(sessionId);
        if (_activeStreamingSessionId == sessionId) {
          _activeStreamingSessionId = null;
        }
        _syncSidebarCacheFromSessions();
      },
      onErrorMessage: (message) {
        _errorMessage = message;
      },
      onStateChanged: notifyListeners,
      onProviderSelected: (provider, model) {
        _activeProvider = provider;
        _activeProviderModelName = model.name;
        _activeCustomProviderId = model.customProviderId;
        notifyListeners();
      },
      onProviderNotice: (message) {
        _statusMessage = message;
        notifyListeners();
      },
    );
  }

  Future<void> testProviderKey(
    AiProviderType provider, {
    required String apiKey,
    String? customProviderId,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      _providerHealthStore.markFailure(
        provider,
        message: 'API key required',
      );
      _errorMessage = '${providerLabel(provider)} API key is empty.';
      notifyListeners();
      return;
    }

    _providerHealthStore.markTesting(provider);
    notifyListeners();

    try {
      await _chatCompletionRepository.validateProviderKey(
        provider: provider,
        apiKey: key,
        customProvider: provider == AiProviderType.custom
            ? _preferences.customProviderForId(customProviderId)
            : null,
      );
      _providerHealthStore.markSuccess(provider);
      _statusMessage = provider == AiProviderType.custom
          ? '${_preferences.customProviderForId(customProviderId)?.normalizedName ?? providerLabel(provider)} key verified.'
          : '${providerLabel(provider)} key verified.';
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      _providerHealthStore.markFailure(
        provider,
        message: message,
      );
      _errorMessage = message;
    }
    notifyListeners();
  }

  Future<void> fetchModelsFromProvider(
    AiProviderType provider, {
    required String apiKey,
    String? customProviderId,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      _errorMessage =
          '${providerLabel(provider)} API key is empty. Please add your API key in Settings.';
      notifyListeners();
      return;
    }

    _statusMessage = 'Fetching models from ${providerLabel(provider)}...';
    notifyListeners();

    try {
      List<ModelOption> newModels = [];

      if (provider == AiProviderType.openRouter) {
        final remoteDataSource = OpenRouterRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);

        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'OpenRouter model',
                  ),
                  description: model.description,
                  provider: AiProviderType.openRouter,
                  visionSupport: model.supportsVision
                      ? ModelVisionSupport.supported
                      : ModelVisionSupport.unknown,
                  contextWindow: model.contextLength,
                  inputPrice: model.inputPrice,
                  outputPrice: model.outputPrice,
                ))
            .toList();
      } else if (provider == AiProviderType.groq) {
        final remoteDataSource = GroqRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);

        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'Groq model',
                  ),
                  description: model.description,
                  provider: AiProviderType.groq,
                  visionSupport: model.supportsVision
                      ? ModelVisionSupport.supported
                      : ModelVisionSupport.unknown,
                  contextWindow: model.contextLength,
                ))
            .toList();
      } else if (provider == AiProviderType.gemini) {
        final remoteDataSource = GeminiRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);

        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'Gemini model',
                  ),
                  description: model.description,
                  provider: AiProviderType.gemini,
                  visionSupport: model.supportsVision
                      ? ModelVisionSupport.supported
                      : ModelVisionSupport.unknown,
                  contextWindow: model.contextLength,
                  maxOutputTokens: model.outputTokenLimit,
                ))
            .toList();
      } else if (provider == AiProviderType.cerebras) {
        final remoteDataSource = CerebrasRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);

        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'Cerebras model',
                  ),
                  description: model.description,
                  provider: AiProviderType.cerebras,
                  visionSupport: model.supportsVision
                      ? ModelVisionSupport.supported
                      : ModelVisionSupport.unknown,
                  contextWindow: model.contextLength,
                ))
            .toList();
      } else if (provider == AiProviderType.zAi) {
        final remoteDataSource = ZaiRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);

        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'Z.ai model',
                  ),
                  description: model.description,
                  provider: AiProviderType.zAi,
                  visionSupport: model.supportsVision
                      ? ModelVisionSupport.supported
                      : ModelVisionSupport.unknown,
                  contextWindow: model.contextLength,
                ))
            .toList();
      } else if (provider == AiProviderType.mistral) {
        final remoteDataSource = MistralRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);
        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'Mistral model',
                  ),
                  description: model.description,
                  provider: AiProviderType.mistral,
                  visionSupport: model.visionSupport,
                  contextWindow: model.contextLength,
                  maxOutputTokens: model.maxOutputTokens,
                ))
            .toList();
      } else if (provider == AiProviderType.sambanova) {
        final remoteDataSource = SambanovaRemoteDataSource();
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);
        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: 'Sambanova model',
                  ),
                  description: model.description,
                  provider: AiProviderType.sambanova,
                  visionSupport: model.visionSupport,
                  contextWindow: model.contextLength,
                  maxOutputTokens: model.maxOutputTokens,
                  inputPrice: model.inputPrice,
                  outputPrice: model.outputPrice,
                ))
            .toList();
      } else if (provider == AiProviderType.custom) {
        final customProvider =
            _preferences.customProviderForId(customProviderId);
        if (customProvider == null) {
          throw Exception('Custom provider configuration is missing.');
        }
        final remoteDataSource = CustomOpenAiRemoteDataSource(
          config: customProvider,
        );
        final fetchedModels = await remoteDataSource.fetchModels(apiKey: key);
        newModels = fetchedModels
            .map((model) => ModelOption(
                  name: model.name,
                  id: model.id,
                  blurb: _truncateModelBlurb(
                    model.description,
                    fallback: '${customProvider.normalizedName} model',
                  ),
                  description: model.description,
                  provider: AiProviderType.custom,
                  customProviderId: customProvider.id,
                  visionSupport: model.supportsVision
                      ? ModelVisionSupport.supported
                      : ModelVisionSupport.unknown,
                  contextWindow: model.contextLength,
                ))
            .toList();
      } else {
        _statusMessage =
            'Model fetching not yet implemented for ${providerLabel(provider)}.';
        notifyListeners();
        return;
      }

      // Merge with existing models (keep models from other providers)
      final existingOtherProviders = provider == AiProviderType.custom
          ? models
              .where(
                (m) =>
                    m.provider != AiProviderType.custom ||
                    m.customProviderId != customProviderId,
              )
              .toList()
          : models.where((m) => m.provider != provider).toList();
      models = [...existingOtherProviders, ...newModels];
      final selectedModel = _preferences.selectedModel;
      final nextSelectedModel = selectedModel == null
          ? null
          : resolveModelOptionSelection(
              models,
              id: selectedModel.id,
              name: selectedModel.name,
              provider: selectedModel.provider,
              customProviderId: selectedModel.customProviderId,
            );
      _preferences = _preferences.update(
        apiKey: _preferences.apiKey,
        systemPrompt: _preferences.systemPrompt,
        model: nextSelectedModel,
        themeMode: _preferences.themeMode,
        appearanceMode: _preferences.appearanceMode,
        dynamicThemeEnabled: _preferences.dynamicThemeEnabled,
        providerKeys: _preferences.providerKeys,
        customProvider: _preferences.customProvider,
        customProviders: _preferences.customProviders,
        routingMode: _preferences.routingMode,
        enabledProviders: _preferences.enabledProviders,
        uiDensityMode: _preferences.uiDensityMode,
        appFontPreset: _preferences.appFontPreset,
        chatFontPreset: _preferences.chatFontPreset,
        chatColorMode: _preferences.chatColorMode,
      );

      await _settingsRepository.saveSettings(
        apiKey: _preferences.apiKey,
        selectedModel: _preferences.selectedModel,
        systemPrompt: _preferences.systemPrompt,
        themeMode: _preferences.themeMode,
        appearanceMode: _preferences.appearanceMode,
        dynamicThemeEnabled: _preferences.dynamicThemeEnabled,
        fetchedModels: models,
        providerKeys: _preferences.providerKeys,
        customProvider: _preferences.customProvider,
        customProviders: _preferences.customProviders,
        routingMode: _preferences.routingMode,
        enabledProviders: _preferences.enabledProviders,
        uiDensityMode: _preferences.uiDensityMode,
        appFontPreset: _preferences.appFontPreset,
        chatFontPreset: _preferences.chatFontPreset,
        chatColorMode: _preferences.chatColorMode,
        selectedProvider: _selectedProvider,
      );

      _statusMessage =
          'Fetched ${newModels.length} models from ${providerLabel(provider)}.';
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      _errorMessage =
          'Failed to fetch models from ${providerLabel(provider)}: $message';
    }
    notifyListeners();
  }

  Future<void> saveCustomProviders(
    List<CustomProviderConfig> customProviders, {
    ModelOption? selectedModel,
  }) async {
    await saveSettings(
      apiKey: _preferences.apiKey,
      systemPrompt: _preferences.systemPrompt,
      model: selectedModel ?? _preferences.selectedModel,
      themeMode: _preferences.themeMode,
      appearanceMode: _preferences.appearanceMode,
      dynamicThemeEnabled: _preferences.dynamicThemeEnabled,
      providerKeys: _preferences.providerKeys.copyWith(custom: ''),
      customProviders: customProviders,
      routingMode: _preferences.routingMode,
      enabledProviders: _preferences.enabledProviders,
      uiDensityMode: _preferences.uiDensityMode,
      appFontPreset: _preferences.appFontPreset,
      chatFontPreset: _preferences.chatFontPreset,
      chatColorMode: _preferences.chatColorMode,
    );
  }

  Future<void> deleteCustomProvider(String customProviderId) async {
    final remainingProviders = _preferences.customProviders
        .where((provider) => provider.id != customProviderId)
        .toList();
    final selectedModel =
        _preferences.selectedModel?.customProviderId == customProviderId
            ? null
            : _preferences.selectedModel;
    await saveCustomProviders(
      remainingProviders,
      selectedModel: selectedModel,
    );
  }

  Future<void> fetchModelsFromCustomProvider(String customProviderId) async {
    final customProvider = _preferences.customProviderForId(customProviderId);
    if (customProvider == null) {
      _errorMessage = 'Custom provider configuration is missing.';
      notifyListeners();
      return;
    }
    await fetchModelsFromProvider(
      AiProviderType.custom,
      apiKey: customProvider.apiKey,
      customProviderId: customProviderId,
    );
  }

  String _truncateModelBlurb(
    String description, {
    required String fallback,
  }) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return fallback;
    if (trimmed.length <= 50) return trimmed;
    return trimmed.substring(0, 50);
  }

  Future<void> _hydrateChats() async {
    _isHydratingChats = true;
    notifyListeners();
    try {
      await _chatSessionStore.load();
      final hydratedSessions =
          _mergeSessionMetadata(_chatSessionStore.sessions);
      final selectedId = _chatSessionStore.selectedSession?.id;
      final selectedSession = selectedId == null
          ? (hydratedSessions.isNotEmpty ? hydratedSessions.first : null)
          : hydratedSessions
              .where((session) => session.id == selectedId)
              .fold<ChatSession?>(
                hydratedSessions.isNotEmpty ? hydratedSessions.first : null,
                (current, session) => session,
              );
      _chatSessionStore.reset(
        sessions: hydratedSessions,
        selectedSession: selectedSession,
      );
      _cachedSidebarSessions =
          _chatSessionStore.sessions.map(_sidebarSnapshotFor).toList();
      await _settingsRepository.saveSidebarCache(_cachedSidebarSessions);
    } catch (_) {
      // Keep cached sidebar data visible if hydration fails.
    } finally {
      _hasHydratedChats = true;
      _isHydratingChats = false;
      notifyListeners();
    }
  }

  void _syncSidebarCacheFromSessions() {
    if (_chatSessionStore.sessions.isEmpty) {
      _cachedSidebarSessions = const <ChatSession>[];
      if (_isReady) {
        unawaited(_settingsRepository.clearSidebarCache());
      }
      return;
    }
    _cachedSidebarSessions =
        _chatSessionStore.sessions.map(_sidebarSnapshotFor).toList();
    if (_isReady) {
      unawaited(_settingsRepository.saveSidebarCache(_cachedSidebarSessions));
    }
  }

  List<ChatSession> _mergeSessionMetadata(List<ChatSession> sessions) {
    if (_cachedSidebarSessions.isEmpty) {
      return List<ChatSession>.from(sessions)..sort(compareChatSessions);
    }
    final metadataById = {
      for (final session in _cachedSidebarSessions) session.id: session,
    };
    return sessions.map((session) {
      final metadata = metadataById[session.id];
      if (metadata == null) return session;
      return session.copyWith(
        isStarred: metadata.isStarred,
        isPinned: metadata.isPinned,
      );
    }).toList()
      ..sort(compareChatSessions);
  }

  AiProviderType? _normalizeSelectedProvider(
    AiProviderType? provider, {
    required List<AiProviderType> enabledProviders,
  }) {
    if (provider == null) return null;
    if (!enabledProviders.contains(provider)) return null;
    return provider;
  }

  bool _didCustomProviderEndpointChange(
    CustomProviderConfig previous,
    CustomProviderConfig next,
  ) {
    return previous.normalizedBaseUrl != next.normalizedBaseUrl;
  }

  List<ModelOption> _reconcileCustomModels(
    List<ModelOption> currentModels, {
    required List<CustomProviderConfig> previousCustomProviders,
    required List<CustomProviderConfig> nextCustomProviders,
  }) {
    return currentModels.where((model) {
      if (model.provider != AiProviderType.custom) return true;
      final customProviderId = model.customProviderId;
      final nextProvider =
          findCustomProviderById(nextCustomProviders, customProviderId);
      if (nextProvider == null) return false;
      final previousProvider =
          findCustomProviderById(previousCustomProviders, customProviderId);
      if (previousProvider == null) return true;
      return !_didCustomProviderEndpointChange(previousProvider, nextProvider);
    }).toList();
  }

  List<AiProviderType> _withCustomProviderEnabledState(
    List<AiProviderType> providers,
    List<CustomProviderConfig> customProviders,
  ) {
    final next = providers
        .where((provider) => provider != AiProviderType.custom)
        .toList();
    if (customProviders.any((provider) => provider.enabled)) {
      next.add(AiProviderType.custom);
    }
    return next;
  }

  String? _normalizeSelectedCustomProviderId(
    AiProviderType? provider, {
    String? preferredCustomProviderId,
  }) {
    if (provider != AiProviderType.custom) return null;
    final matchingProvider = _preferences.customProviderForId(
      preferredCustomProviderId,
    );
    if (matchingProvider != null) {
      return matchingProvider.id;
    }
    if (_preferences.customProviders.isEmpty) return null;
    return _preferences.customProviders.first.id;
  }

  String _modelPickerScrollOffsetKey(
    AiProviderType? provider, {
    String? customProviderId,
  }) {
    if (provider == AiProviderType.custom &&
        (customProviderId ?? '').trim().isNotEmpty) {
      return 'custom:${customProviderId!.trim()}';
    }
    return provider?.name ?? '__all__';
  }

  @override
  // ignore: must_call_super
  void dispose() {
    _chatStreamingCoordinator.dispose();
    _database?.close();
    _chatCompletionRepository.dispose();
  }
}

ChatSession _sidebarSnapshotFor(ChatSession session) {
  return ChatSession(
    id: session.id,
    title: session.title,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    messages: const <ChatMessage>[],
    isStarred: session.isStarred,
    isPinned: session.isPinned,
  );
}

Stream<String> _emptyChatCompletionStreamFactory({
  required ProviderKeys providerKeys,
  required List<CustomProviderConfig> customProviders,
  required ModelOption model,
  required ChatRoutingMode routingMode,
  required List<AiProviderType> enabledProviders,
  required String systemPrompt,
  required List<ChatMessage> history,
  void Function(AiProviderType provider, ModelOption model)? onProviderSelected,
  void Function(String message)? onProviderNotice,
}) {
  return const Stream<String>.empty();
}

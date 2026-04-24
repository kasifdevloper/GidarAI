import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/app_descriptors.dart';
import '../../core/models/app_models.dart';

class SettingsRepository {
  SettingsRepository(
    this._prefs, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? FlutterSecureStorage();

  static const apiKeyKey = 'api_key';
  static const providerKeysKey = 'provider_keys';
  static const customProviderKey = 'custom_provider';
  static const customProvidersKey = 'custom_providers';
  static const selectedModelIdKey = 'selected_model_id';
  static const selectedModelNameKey = 'selected_model_name';
  static const selectedModelProviderKey = 'selected_model_provider';
  static const selectedModelCustomProviderIdKey =
      'selected_model_custom_provider_id';
  static const selectedProviderKey = 'selected_provider';
  static const systemPromptKey = 'system_prompt';
  static const appThemeKey = 'app_theme';
  static const appearanceModeKey = 'appearance_mode';
  static const dynamicThemeEnabledKey = 'dynamic_theme_enabled';
  static const appFontPresetKey = 'app_font_preset';
  static const chatFontPresetKey = 'chat_font_preset';
  static const chatColorModeKey = 'chat_color_mode';
  static const sidebarCacheKey = 'sidebar_chat_cache';
  static const modelPickerScrollOffsetsKey = 'model_picker_scroll_offsets';
  static const _sidebarCacheLimit = 24;
  static const fetchedModelsKey = 'fetched_models';
  static const _legacyCustomModelsKey = 'custom_models';
  static const routingModeKey = 'routing_mode';
  static const enabledProvidersKey = 'enabled_providers';
  static const uiDensityKey = 'ui_density_mode';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  static const List<ModelOption> builtInModels = <ModelOption>[
    ModelOption(
      name: 'OpenRouter Probe',
      id: 'openai/gpt-4o-mini',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.openRouter,
    ),
    ModelOption(
      name: 'Groq Probe',
      id: 'llama-3.1-8b-instant',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.groq,
    ),
    ModelOption(
      name: 'Gemini Probe',
      id: 'gemini-1.5-flash',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.gemini,
      supportsVision: true,
    ),
    ModelOption(
      name: 'Cerebras Probe',
      id: 'llama3.1-8b',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.cerebras,
    ),
    ModelOption(
      name: 'Z.ai Probe',
      id: 'glm-4.6',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.zAi,
    ),
    ModelOption(
      name: 'Mistral Probe',
      id: 'mistral-small-latest',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.mistral,
    ),
    ModelOption(
      name: 'Sambanova Probe',
      id: 'Meta-Llama-3.1-8B-Instruct',
      blurb: 'Compatibility probe model',
      provider: AiProviderType.sambanova,
    ),
  ];

  Future<AppSettings> loadSettings() async {
    final fetchedModelsRaw = _prefs.getString(fetchedModelsKey) ??
        _prefs.getString(_legacyCustomModelsKey);
    final fetchedModels = _decodeModels(fetchedModelsRaw);
    final providerKeys = await _decodeProviderKeys();
    final customProviders = await _decodeCustomProviders(providerKeys);
    final customProvider = customProviders.isEmpty
        ? const CustomProviderConfig()
        : customProviders.first;
    final selectedId = _prefs.getString(selectedModelIdKey);
    final selectedModelProvider =
        AiProviderType.values.cast<AiProviderType?>().firstWhere(
              (provider) =>
                  provider?.name == _prefs.getString(selectedModelProviderKey),
              orElse: () => null,
            );
    final selectedProvider =
        AiProviderType.values.cast<AiProviderType?>().firstWhere(
              (provider) =>
                  provider?.name == _prefs.getString(selectedProviderKey),
              orElse: () => null,
            );
    final selectedName = _prefs.getString(selectedModelNameKey);
    final selectedCustomProviderId =
        _prefs.getString(selectedModelCustomProviderIdKey);
    final selectedModel = resolveModelOptionSelection(
      fetchedModels,
      id: selectedId,
      name: selectedName,
      provider: selectedModelProvider,
      customProviderId: selectedCustomProviderId,
    );
    final themeName = _prefs.getString(appThemeKey);
    final themeMode = AppThemeMode.values.firstWhere(
      (theme) => theme.name == themeName,
      orElse: () => defaultThemeMode,
    );
    final appearanceMode = AppAppearanceMode.values.firstWhere(
      (mode) => mode.name == _prefs.getString(appearanceModeKey),
      orElse: () => defaultAppearanceMode,
    );
    final dynamicThemeEnabled = _prefs.getBool(dynamicThemeEnabledKey) ?? false;
    const routingMode = ChatRoutingMode.directModel;
    final enabledProviders = _decodeEnabledProviders();
    final uiDensityMode = UiDensityMode.values.firstWhere(
      (mode) => mode.name == _prefs.getString(uiDensityKey),
      orElse: () => defaultUiDensityMode,
    );
    final appFontPreset = AppFontPreset.values.firstWhere(
      (preset) => preset.name == _prefs.getString(appFontPresetKey),
      orElse: () => defaultAppFontPreset,
    );
    final chatFontPreset = AppFontPreset.values.firstWhere(
      (preset) => preset.name == _prefs.getString(chatFontPresetKey),
      orElse: () => defaultChatFontPreset,
    );
    final chatColorMode = ChatColorMode.values.firstWhere(
      (mode) => mode.name == _prefs.getString(chatColorModeKey),
      orElse: () => defaultChatColorMode,
    );

    return AppSettings(
      apiKey: providerKeys.openRouter,
      providerKeys: providerKeys,
      customProvider: customProvider,
      customProviders: customProviders,
      selectedModel: selectedModel,
      selectedProvider: selectedProvider,
      systemPrompt: _prefs.getString(systemPromptKey) ?? defaultSystemPrompt,
      themeMode: themeMode,
      appearanceMode: appearanceMode,
      dynamicThemeEnabled: dynamicThemeEnabled,
      fetchedModels: fetchedModels,
      routingMode: routingMode,
      enabledProviders: enabledProviders,
      uiDensityMode: uiDensityMode,
      appFontPreset: appFontPreset,
      chatFontPreset: chatFontPreset,
      chatColorMode: chatColorMode,
    );
  }

  List<ChatSession> loadSidebarCache() {
    final raw = _prefs.getString(sidebarCacheKey);
    if (raw == null || raw.trim().isEmpty) return const <ChatSession>[];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (item) => _sidebarCacheToSession(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList()
        ..sort(compareChatSessions);
    } catch (_) {
      return const <ChatSession>[];
    }
  }

  Map<String, double> loadModelPickerScrollOffsets() {
    final raw = _prefs.getString(modelPickerScrollOffsetsKey);
    if (raw == null || raw.trim().isEmpty) return const <String, double>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    } catch (_) {
      return const <String, double>{};
    }
  }

  Future<void> saveSettings({
    required String apiKey,
    required ModelOption? selectedModel,
    required String systemPrompt,
    required AppThemeMode themeMode,
    AppAppearanceMode appearanceMode = defaultAppearanceMode,
    bool dynamicThemeEnabled = false,
    List<ModelOption>? fetchedModels,
    ProviderKeys? providerKeys,
    CustomProviderConfig? customProvider,
    List<CustomProviderConfig>? customProviders,
    ChatRoutingMode? routingMode,
    List<AiProviderType>? enabledProviders,
    UiDensityMode? uiDensityMode,
    AppFontPreset? appFontPreset,
    AppFontPreset? chatFontPreset,
    ChatColorMode? chatColorMode,
    AiProviderType? selectedProvider,
  }) async {
    final mergedProviderKeys =
        (providerKeys ?? await _decodeProviderKeys()).copyWith(
      openRouter: apiKey,
    );
    await _secureStorage.write(key: apiKeyKey, value: apiKey);
    await _secureStorage.write(
      key: providerKeysKey,
      value: jsonEncode(mergedProviderKeys.toMap()),
    );
    final mergedCustomProviders = customProviders ??
        (customProvider != null
            ? (customProvider.hasAnyData ? [customProvider] : const [])
            : await _decodeCustomProviders(mergedProviderKeys));
    final normalizedCustomProviders =
        mergedCustomProviders.map((provider) => provider.toMap()).toList();
    await _secureStorage.write(
      key: customProvidersKey,
      value: jsonEncode(normalizedCustomProviders),
    );
    await _prefs.remove(apiKeyKey);
    await _prefs.remove(providerKeysKey);
    await _prefs.remove(customProviderKey);
    if (selectedModel == null) {
      await _prefs.remove(selectedModelIdKey);
      await _prefs.remove(selectedModelNameKey);
      await _prefs.remove(selectedModelProviderKey);
      await _prefs.remove(selectedModelCustomProviderIdKey);
    } else {
      await _prefs.setString(selectedModelIdKey, selectedModel.id);
      await _prefs.setString(selectedModelNameKey, selectedModel.name);
      await _prefs.setString(
        selectedModelProviderKey,
        selectedModel.provider.name,
      );
      if ((selectedModel.customProviderId ?? '').trim().isEmpty) {
        await _prefs.remove(selectedModelCustomProviderIdKey);
      } else {
        await _prefs.setString(
          selectedModelCustomProviderIdKey,
          selectedModel.customProviderId!.trim(),
        );
      }
    }
    if (selectedProvider == null) {
      await _prefs.remove(selectedProviderKey);
    } else {
      await _prefs.setString(selectedProviderKey, selectedProvider.name);
    }
    await _prefs.setString(systemPromptKey, systemPrompt);
    await _prefs.setString(appThemeKey, themeMode.name);
    await _prefs.setString(appearanceModeKey, appearanceMode.name);
    await _prefs.setBool(dynamicThemeEnabledKey, dynamicThemeEnabled);
    await _prefs.setString(
      routingModeKey,
      ChatRoutingMode.directModel.name,
    );
    await _prefs.setStringList(
      enabledProvidersKey,
      (enabledProviders ?? _decodeEnabledProviders())
          .map((provider) => provider.name)
          .toList(),
    );
    await _prefs.setString(
      uiDensityKey,
      (uiDensityMode ?? defaultUiDensityMode).name,
    );
    await _prefs.setString(
      appFontPresetKey,
      (appFontPreset ?? defaultAppFontPreset).name,
    );
    await _prefs.setString(
      chatFontPresetKey,
      (chatFontPreset ?? defaultChatFontPreset).name,
    );
    await _prefs.setString(
      chatColorModeKey,
      (chatColorMode ?? defaultChatColorMode).name,
    );
    if (fetchedModels != null) {
      await _prefs.setString(
        fetchedModelsKey,
        jsonEncode(fetchedModels.map((model) => model.toMap()).toList()),
      );
      await _prefs.remove(_legacyCustomModelsKey);
    }
  }

  Future<void> saveSidebarCache(List<ChatSession> sessions) async {
    final payload =
        sessions.take(_sidebarCacheLimit).map(_sessionToSidebarCache).toList();
    await _prefs.setString(sidebarCacheKey, jsonEncode(payload));
  }

  Future<void> clearSidebarCache() async {
    await _prefs.remove(sidebarCacheKey);
  }

  Future<void> saveModelPickerScrollOffsets(Map<String, double> offsets) async {
    await _prefs.setString(
      modelPickerScrollOffsetsKey,
      jsonEncode(offsets),
    );
  }

  Future<void> saveSelectedProvider(AiProviderType? provider) async {
    if (provider == null) {
      await _prefs.remove(selectedProviderKey);
      return;
    }
    await _prefs.setString(selectedProviderKey, provider.name);
  }

  Future<void> clearAll() async {
    await _secureStorage.delete(key: apiKeyKey);
    await _secureStorage.delete(key: providerKeysKey);
    await _secureStorage.delete(key: customProvidersKey);
    await _prefs.remove(apiKeyKey);
    await _prefs.remove(providerKeysKey);
    await _prefs.remove(customProviderKey);
    await _prefs.remove(selectedModelIdKey);
    await _prefs.remove(selectedModelNameKey);
    await _prefs.remove(selectedModelProviderKey);
    await _prefs.remove(selectedModelCustomProviderIdKey);
    await _prefs.remove(selectedProviderKey);
    await _prefs.remove(systemPromptKey);
    await _prefs.remove(appThemeKey);
    await _prefs.remove(appearanceModeKey);
    await _prefs.remove(dynamicThemeEnabledKey);
    await _prefs.remove(fetchedModelsKey);
    await _prefs.remove(_legacyCustomModelsKey);
    await _prefs.remove(routingModeKey);
    await _prefs.remove(enabledProvidersKey);
    await _prefs.remove(uiDensityKey);
    await _prefs.remove(appFontPresetKey);
    await _prefs.remove(chatFontPresetKey);
    await _prefs.remove(chatColorModeKey);
    await _prefs.remove(sidebarCacheKey);
    await _prefs.remove(modelPickerScrollOffsetsKey);
  }

  Map<String, dynamic> _sessionToSidebarCache(ChatSession session) {
    return {
      'id': session.id,
      'title': session.title,
      'createdAt': session.createdAt.toIso8601String(),
      'updatedAt': session.updatedAt.toIso8601String(),
      'isStarred': session.isStarred,
      'isPinned': session.isPinned,
    };
  }

  ChatSession _sidebarCacheToSession(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Untitled chat',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: const <ChatMessage>[],
      isStarred: map['isStarred'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  List<ModelOption> _decodeModels(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) =>
            ModelOption.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<ProviderKeys> _decodeProviderKeys() async {
    final raw = await _secureStorage.read(key: providerKeysKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return ProviderKeys.fromMap(decoded);
    }

    final legacyRaw = _prefs.getString(providerKeysKey);
    final legacyApiKey = _prefs.getString(apiKeyKey) ?? '';
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      final decoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
      final migrated = ProviderKeys.fromMap(decoded).copyWith(
        openRouter: decoded['openRouter'] as String? ?? legacyApiKey,
      );
      await _migrateLegacyProviderKeys(migrated);
      return migrated;
    }

    if (legacyApiKey.isNotEmpty) {
      final migrated = ProviderKeys(openRouter: legacyApiKey);
      await _migrateLegacyProviderKeys(migrated);
      return migrated;
    }

    return const ProviderKeys();
  }

  Future<List<CustomProviderConfig>> _decodeCustomProviders(
    ProviderKeys providerKeys,
  ) async {
    final raw = await _secureStorage.read(key: customProvidersKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .map(
              (item) =>
                  CustomProviderConfig.fromMap(Map<String, dynamic>.from(item)),
            )
            .where((provider) => provider.id.trim().isNotEmpty)
            .toList();
      } catch (_) {}
    }

    final legacyConfigRaw = _prefs.getString(customProviderKey);
    if (legacyConfigRaw != null && legacyConfigRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyConfigRaw) as Map<String, dynamic>;
        final migrated = CustomProviderConfig.fromMap(decoded).copyWith(
          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
          apiKey: providerKeys.custom,
          enabled: _decodeEnabledProviders().contains(AiProviderType.custom),
        );
        final providers = migrated.hasAnyData
            ? <CustomProviderConfig>[migrated]
            : const <CustomProviderConfig>[];
        await _secureStorage.write(
          key: customProvidersKey,
          value: jsonEncode(
              providers.map((provider) => provider.toMap()).toList()),
        );
        await _prefs.remove(customProviderKey);
        return providers;
      } catch (_) {}
    }

    return const <CustomProviderConfig>[];
  }

  Future<void> _migrateLegacyProviderKeys(ProviderKeys providerKeys) async {
    await _secureStorage.write(
      key: apiKeyKey,
      value: providerKeys.openRouter,
    );
    await _secureStorage.write(
      key: providerKeysKey,
      value: jsonEncode(providerKeys.toMap()),
    );
    await _prefs.remove(apiKeyKey);
    await _prefs.remove(providerKeysKey);
  }

  List<AiProviderType> _decodeEnabledProviders() {
    final raw = _prefs.getStringList(enabledProvidersKey);
    if (raw == null || raw.isEmpty) {
      return List<AiProviderType>.from(defaultEnabledProviders);
    }
    return raw
        .map(
          (value) => AiProviderType.values.firstWhere(
            (provider) => provider.name == value,
            orElse: () => AiProviderType.openRouter,
          ),
        )
        .toList();
  }
}

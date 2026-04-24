import '../../data/repository/provider_router.dart';
import 'app_descriptors.dart';
import 'app_models.dart';

class AppPreferencesState {
  const AppPreferencesState({
    required this.apiKey,
    required this.providerKeys,
    this.customProvider = const CustomProviderConfig(),
    this.customProviders = const <CustomProviderConfig>[],
    required this.systemPrompt,
    required this.selectedModel,
    required this.themeMode,
    required this.appearanceMode,
    required this.dynamicThemeEnabled,
    required this.routingMode,
    required this.enabledProviders,
    required this.uiDensityMode,
    required this.appFontPreset,
    required this.chatFontPreset,
    required this.chatColorMode,
  });

  factory AppPreferencesState.initial({ModelOption? defaultModel}) {
    return AppPreferencesState(
      apiKey: '',
      providerKeys: const ProviderKeys(),
      customProvider: const CustomProviderConfig(),
      customProviders: const <CustomProviderConfig>[],
      systemPrompt: defaultSystemPrompt,
      selectedModel: defaultModel,
      themeMode: defaultThemeMode,
      appearanceMode: defaultAppearanceMode,
      dynamicThemeEnabled: false,
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: List<AiProviderType>.from(defaultEnabledProviders),
      uiDensityMode: defaultUiDensityMode,
      appFontPreset: defaultAppFontPreset,
      chatFontPreset: defaultChatFontPreset,
      chatColorMode: defaultChatColorMode,
    );
  }

  factory AppPreferencesState.fromStored(
    AppSettings settings, {
    required List<ModelOption> availableModels,
  }) {
    return AppPreferencesState(
      apiKey: settings.apiKey,
      providerKeys: settings.providerKeys,
      customProvider: settings.customProvider,
      customProviders:
          List<CustomProviderConfig>.from(settings.customProviders),
      systemPrompt: settings.systemPrompt,
      selectedModel: resolveModelOptionSelection(
        availableModels,
        id: settings.selectedModel?.id,
        name: settings.selectedModel?.name,
        provider: settings.selectedModel?.provider,
        customProviderId: settings.selectedModel?.customProviderId,
      ),
      themeMode: settings.themeMode,
      appearanceMode: settings.appearanceMode,
      dynamicThemeEnabled: settings.dynamicThemeEnabled,
      routingMode: settings.routingMode,
      enabledProviders: List<AiProviderType>.from(settings.enabledProviders),
      uiDensityMode: settings.uiDensityMode,
      appFontPreset: settings.appFontPreset,
      chatFontPreset: settings.chatFontPreset,
      chatColorMode: settings.chatColorMode,
    );
  }

  final String apiKey;
  final ProviderKeys providerKeys;
  final CustomProviderConfig customProvider;
  final List<CustomProviderConfig> customProviders;
  final String systemPrompt;
  final ModelOption? selectedModel;
  final AppThemeMode themeMode;
  final AppAppearanceMode appearanceMode;
  final bool dynamicThemeEnabled;
  final ChatRoutingMode routingMode;
  final List<AiProviderType> enabledProviders;
  final UiDensityMode uiDensityMode;
  final AppFontPreset appFontPreset;
  final AppFontPreset chatFontPreset;
  final ChatColorMode chatColorMode;

  bool get hasAnyEnabledProviderKey {
    return enabledProviders.any((provider) {
      if (provider == AiProviderType.custom) {
        return customProviders.any(
          (customProvider) =>
              customProvider.enabled && customProvider.hasApiKey,
        );
      }
      return providerKeys.keyFor(provider).trim().isNotEmpty;
    });
  }

  bool hasReachableProviderKey(ProviderRouter router) {
    final selectedModel = this.selectedModel;
    if (selectedModel == null) return false;
    final chain = router.resolveChain(
      routingMode: routingMode,
      selectedModel: selectedModel,
      enabledProviders: enabledProviders,
    );
    return chain.any((provider) {
      if (provider == AiProviderType.custom) {
        final customProvider =
            customProviderForId(selectedModel.customProviderId);
        return customProvider != null &&
            customProvider.enabled &&
            customProvider.hasApiKey;
      }
      return providerKeys.keyFor(provider).trim().isNotEmpty;
    });
  }

  CustomProviderConfig? customProviderForId(String? id) {
    return findCustomProviderById(customProviders, id);
  }

  String providerLabelForModel(ModelOption? model) {
    if (model == null) return 'All Providers';
    if (model.provider != AiProviderType.custom) {
      return providerLabel(model.provider);
    }
    return customProviderForId(model.customProviderId)?.normalizedName ??
        providerLabel(model.provider);
  }

  AppPreferencesState update({
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
  }) {
    final normalizedApiKey = apiKey.trim();
    final nextCustomProviders = List<CustomProviderConfig>.from(
      customProviders ?? this.customProviders,
    );
    return AppPreferencesState(
      apiKey: normalizedApiKey,
      providerKeys: (providerKeys ?? this.providerKeys)
          .copyWith(openRouter: normalizedApiKey),
      customProvider: customProvider ??
          (nextCustomProviders.isNotEmpty
              ? nextCustomProviders.first
              : this.customProvider),
      customProviders: nextCustomProviders,
      systemPrompt: systemPrompt.trim().isEmpty
          ? defaultSystemPrompt
          : systemPrompt.trim(),
      selectedModel: model,
      themeMode: themeMode,
      appearanceMode: appearanceMode ?? this.appearanceMode,
      dynamicThemeEnabled: dynamicThemeEnabled ?? this.dynamicThemeEnabled,
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: List<AiProviderType>.from(
        enabledProviders ?? this.enabledProviders,
      ),
      uiDensityMode: uiDensityMode ?? this.uiDensityMode,
      appFontPreset: appFontPreset ?? this.appFontPreset,
      chatFontPreset: chatFontPreset ?? this.chatFontPreset,
      chatColorMode: chatColorMode ?? this.chatColorMode,
    );
  }
}

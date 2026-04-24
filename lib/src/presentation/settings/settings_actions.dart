import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/app_controller.dart';
import 'settings_view_model.dart';

class SettingsFormSnapshot {
  const SettingsFormSnapshot({
    required this.apiKey,
    required this.groqKey,
    required this.geminiKey,
    required this.cerebrasKey,
    required this.zAiKey,
    this.mistralKey = '',
    this.sambanovaKey = '',
    this.customKey = '',
    this.customProviderName = '',
    this.customProviderBaseUrl = '',
    required this.systemPrompt,
  });

  final String apiKey;
  final String groqKey;
  final String geminiKey;
  final String cerebrasKey;
  final String zAiKey;
  final String mistralKey;
  final String sambanovaKey;
  final String customKey;
  final String customProviderName;
  final String customProviderBaseUrl;
  final String systemPrompt;

  ProviderKeys mergeProviderKeys(ProviderKeys base) {
    return base.copyWith(
      openRouter: apiKey.trim(),
      groq: groqKey.trim(),
      gemini: geminiKey.trim(),
      cerebras: cerebrasKey.trim(),
      zAi: zAiKey.trim(),
      mistral: mistralKey.trim(),
      sambanova: sambanovaKey.trim(),
      custom: customKey.trim(),
    );
  }

  CustomProviderConfig mergeCustomProvider(CustomProviderConfig base) {
    return base.copyWith(
      name: customProviderName.trim(),
      baseUrl: customProviderBaseUrl.trim(),
    );
  }
}

class SettingsActions {
  const SettingsActions(this._controller);

  const SettingsActions.test() : _controller = null;

  final AppController? _controller;

  Future<void> save({
    required SettingsViewModel vm,
    required SettingsFormSnapshot form,
    ModelOption? model,
    AppThemeMode? themeMode,
    AppAppearanceMode? appearanceMode,
    bool? dynamicThemeEnabled,
    ProviderKeys? providerKeys,
    CustomProviderConfig? customProvider,
    ChatRoutingMode? routingMode,
    List<AiProviderType>? enabledProviders,
    UiDensityMode? uiDensityMode,
    AppFontPreset? appFontPreset,
    AppFontPreset? chatFontPreset,
    ChatColorMode? chatColorMode,
  }) {
    final mergedProviderKeys =
        form.mergeProviderKeys(providerKeys ?? vm.providerKeys);
    return _controller!.saveSettings(
      apiKey: form.apiKey,
      systemPrompt: form.systemPrompt,
      model: model ?? vm.selectedModel,
      themeMode: themeMode ?? vm.themeMode,
      appearanceMode: appearanceMode ?? vm.appearanceMode,
      dynamicThemeEnabled: dynamicThemeEnabled ?? vm.dynamicThemeEnabled,
      providerKeys: mergedProviderKeys,
      routingMode: routingMode ?? vm.routingMode,
      enabledProviders: enabledProviders ?? vm.enabledProviders,
      uiDensityMode: uiDensityMode ?? vm.uiDensityMode,
      appFontPreset: appFontPreset ?? vm.appFontPreset,
      chatFontPreset: chatFontPreset ?? vm.chatFontPreset,
      chatColorMode: chatColorMode ?? vm.chatColorMode,
    );
  }

  Future<void> testProviderKey(
    AiProviderType provider, {
    required String apiKey,
  }) {
    return _controller!.testProviderKey(provider, apiKey: apiKey);
  }

  List<AiProviderType> toggleProvider(
    List<AiProviderType> current,
    AiProviderType provider,
    bool enabled,
  ) {
    final next = [...current];
    if (enabled) {
      if (!next.contains(provider)) {
        next.add(provider);
      }
      return next;
    }
    next.remove(provider);
    return next;
  }
}

final settingsActionsProvider = Provider<SettingsActions>(
  (ref) => SettingsActions(ref.read(appControllerProvider)),
  dependencies: [appControllerProvider],
);

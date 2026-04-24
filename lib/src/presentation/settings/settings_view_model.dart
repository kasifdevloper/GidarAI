import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_descriptors.dart';
import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class SettingsViewModel {
  const SettingsViewModel({
    required this.apiKey,
    required this.appVersionLabel,
    required this.providerKeys,
    required this.customProvider,
    required this.customProviders,
    required this.systemPrompt,
    required this.selectedModel,
    required this.models,
    required this.themeMode,
    required this.appearanceMode,
    required this.dynamicThemeEnabled,
    required this.dynamicThemeAvailable,
    required this.themes,
    required this.routingMode,
    required this.enabledProviders,
    required this.uiDensityMode,
    required this.appFontPreset,
    required this.chatFontPreset,
    required this.chatColorMode,
    required this.fontPresets,
    required this.providerSummaries,
  });

  final String apiKey;
  final String appVersionLabel;
  final ProviderKeys providerKeys;
  final CustomProviderConfig customProvider;
  final List<CustomProviderConfig> customProviders;
  final String systemPrompt;
  final ModelOption? selectedModel;
  final List<ModelOption> models;
  final AppThemeMode themeMode;
  final AppAppearanceMode appearanceMode;
  final bool dynamicThemeEnabled;
  final bool dynamicThemeAvailable;
  final List<ThemePalette> themes;
  final ChatRoutingMode routingMode;
  final List<AiProviderType> enabledProviders;
  final UiDensityMode uiDensityMode;
  final AppFontPreset appFontPreset;
  final AppFontPreset chatFontPreset;
  final ChatColorMode chatColorMode;
  final List<AppFontPreset> fontPresets;
  final List<ProviderHealthSummary> providerSummaries;

  List<ModelOption> modelsFor(AiProviderType provider) {
    return models.where((model) => model.provider == provider).toList();
  }

  List<ModelOption> modelsForCustomProvider(String customProviderId) {
    return models
        .where(
          (model) =>
              model.provider == AiProviderType.custom &&
              model.customProviderId == customProviderId,
        )
        .toList();
  }

  bool get hasCustomProvider {
    return customProviders.isNotEmpty ||
        models.any((model) => model.provider == AiProviderType.custom) ||
        selectedModel?.provider == AiProviderType.custom;
  }

  String get customProviderLabel => customProvider.normalizedName;

  String providerLabelForModel(ModelOption? model) {
    if (model == null) return 'All Providers';
    if (model.provider != AiProviderType.custom) {
      return providerLabel(model.provider);
    }
    return findCustomProviderById(customProviders, model.customProviderId)
            ?.normalizedName ??
        providerLabel(model.provider);
  }
}

final settingsViewModelProvider = Provider<SettingsViewModel>(
  (ref) {
    final controller = ref.watch(appControllerProvider);
    return SettingsViewModel(
      apiKey: controller.apiKey,
      appVersionLabel: controller.appVersionLabel,
      providerKeys: controller.providerKeys,
      customProvider: controller.customProvider,
      customProviders: controller.customProviders,
      systemPrompt: controller.systemPrompt,
      selectedModel: controller.selectedModel,
      models: controller.models,
      themeMode: controller.themeMode,
      appearanceMode: controller.appearanceMode,
      dynamicThemeEnabled: controller.dynamicThemeEnabled,
      dynamicThemeAvailable: controller.dynamicThemeAvailable,
      themes: List<ThemePalette>.from(palettes),
      routingMode: controller.routingMode,
      enabledProviders: controller.enabledProviders,
      uiDensityMode: controller.uiDensityMode,
      appFontPreset: controller.appFontPreset,
      chatFontPreset: controller.chatFontPreset,
      chatColorMode: controller.chatColorMode,
      fontPresets: List<AppFontPreset>.from(fontPresetCatalog),
      providerSummaries: AiProviderType.values.map((provider) {
        final hasKey = provider == AiProviderType.custom
            ? controller.customProviders.any(
                (customProvider) => customProvider.hasApiKey,
              )
            : controller.providerKeys.keyFor(provider).trim().isNotEmpty;
        return ProviderHealthSummary(
          provider: provider,
          hasKey: hasKey,
          enabled: controller.enabledProviders.contains(provider),
          status: controller.providerCheckFor(provider),
          label: providerLabel(provider),
          note: providerNote(provider),
        );
      }).toList(),
    );
  },
  dependencies: [appControllerProvider],
);

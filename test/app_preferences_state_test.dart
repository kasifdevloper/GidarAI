import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/core/models/app_preferences_state.dart';
import 'package:gidar_ai_flutter/src/data/repository/provider_router.dart';

void main() {
  test('update normalizes fields and syncs openRouter key', () {
    const model = ModelOption(
      name: 'Test Model',
      id: 'test-model',
      blurb: 'Test blurb',
      provider: AiProviderType.groq,
    );
    final state = AppPreferencesState.initial().update(
      apiKey: '  secret-key  ',
      systemPrompt: '   ',
      model: model,
      themeMode: AppThemeMode.oceanTeal,
      appearanceMode: AppAppearanceMode.system,
      enabledProviders: const [AiProviderType.groq],
    );

    expect(state.apiKey, 'secret-key');
    expect(state.providerKeys.openRouter, 'secret-key');
    expect(state.systemPrompt, isNotEmpty);
    expect(state.selectedModel?.id, 'test-model');
    expect(state.themeMode, AppThemeMode.oceanTeal);
    expect(state.appearanceMode, AppAppearanceMode.system);
    expect(state.appFontPreset, AppFontPreset.systemDynamic);
    expect(state.chatFontPreset, AppFontPreset.notoSansDevanagari);
    expect(state.chatColorMode, ChatColorMode.theme);
  });

  test('reachable provider key requires the selected model provider', () {
    const state = AppPreferencesState(
      apiKey: '',
      providerKeys: ProviderKeys(groq: 'groq-key'),
      customProvider: CustomProviderConfig(),
      systemPrompt: 'hello',
      selectedModel: ModelOption(
        name: 'Vision Model',
        id: 'vision-model',
        blurb: 'vision',
        provider: AiProviderType.gemini,
      ),
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      dynamicThemeEnabled: false,
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: [AiProviderType.groq, AiProviderType.gemini],
      uiDensityMode: UiDensityMode.compact,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.sourceSans3,
      chatColorMode: ChatColorMode.colorful,
    );

    expect(state.hasAnyEnabledProviderKey, isTrue);
    expect(state.hasReachableProviderKey(const ProviderRouter()), isFalse);
  });

  test(
      'initial defaults use system app font and noto sans devanagari chat font',
      () {
    final state = AppPreferencesState.initial();

    expect(state.selectedModel, isNull);
    expect(state.appearanceMode, AppAppearanceMode.system);
    expect(state.enabledProviders, isEmpty);
    expect(state.appFontPreset, AppFontPreset.systemDynamic);
    expect(state.chatFontPreset, AppFontPreset.notoSansDevanagari);
    expect(state.chatColorMode, ChatColorMode.theme);
  });
}

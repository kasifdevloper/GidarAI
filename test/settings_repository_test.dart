import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/data/repository/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('font presets persist and restore from settings repository', () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = SettingsRepository(
      prefs,
      secureStorage: _FakeSecureStorage(),
    );
    final selectedModel = SettingsRepository.builtInModels.first;

    await repository.saveSettings(
      apiKey: 'demo-key',
      selectedModel: selectedModel,
      systemPrompt: 'Hello',
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.system,
      appFontPreset: AppFontPreset.sourceSans3,
      chatFontPreset: AppFontPreset.notoSansDevanagari,
      chatColorMode: ChatColorMode.colorful,
      providerKeys: const ProviderKeys(openRouter: 'demo-key'),
      enabledProviders: const [AiProviderType.openRouter],
    );

    final restored = await repository.loadSettings();

    expect(restored.appFontPreset, AppFontPreset.sourceSans3);
    expect(restored.chatFontPreset, AppFontPreset.notoSansDevanagari);
    expect(restored.chatColorMode, ChatColorMode.colorful);
  });

  test('selected model restores independently from selected provider filter',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = SettingsRepository(
      prefs,
      secureStorage: _FakeSecureStorage(),
    );
    const selectedModel = ModelOption(
      name: 'OpenRouter Real Model',
      id: 'openrouter/real-model',
      blurb: 'Real model',
      provider: AiProviderType.openRouter,
    );

    await repository.saveSettings(
      apiKey: 'demo-key',
      selectedModel: selectedModel,
      selectedProvider: AiProviderType.gemini,
      systemPrompt: 'Hello',
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.system,
      providerKeys: const ProviderKeys(openRouter: 'demo-key'),
      fetchedModels: const [
        ModelOption(
          name: 'Gemini Probe',
          id: 'gemini-1.5-flash',
          blurb: 'Probe model',
          provider: AiProviderType.gemini,
        ),
        selectedModel,
      ],
      enabledProviders: const [
        AiProviderType.openRouter,
        AiProviderType.gemini,
      ],
    );

    final restored = await repository.loadSettings();

    expect(restored.selectedProvider, AiProviderType.gemini);
    expect(restored.selectedModel?.provider, AiProviderType.openRouter);
    expect(restored.selectedModel?.name, 'OpenRouter Real Model');
    expect(restored.selectedModel?.id, 'openrouter/real-model');
  });

  test('repository defaults to system appearance and no enabled providers',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final repository = SettingsRepository(
      prefs,
      secureStorage: _FakeSecureStorage(),
    );

    final restored = await repository.loadSettings();

    expect(restored.appearanceMode, AppAppearanceMode.system);
    expect(restored.enabledProviders, isEmpty);
  });
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
}

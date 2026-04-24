import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/presentation/settings/settings_actions.dart';

void main() {
  test('SettingsFormSnapshot merges and trims provider keys', () {
    const snapshot = SettingsFormSnapshot(
      apiKey: '  openrouter-key  ',
      groqKey: ' groq-key ',
      geminiKey: 'gemini-key',
      cerebrasKey: '  ',
      zAiKey: 'zai-key ',
      systemPrompt: 'hello',
    );

    final merged = snapshot.mergeProviderKeys(
      const ProviderKeys(cerebras: 'existing-cerebras'),
    );

    expect(merged.openRouter, 'openrouter-key');
    expect(merged.groq, 'groq-key');
    expect(merged.gemini, 'gemini-key');
    expect(merged.cerebras, '');
    expect(merged.zAi, 'zai-key');
  });

  test('toggleProvider adds once and removes cleanly', () {
    const actions = SettingsActions.test();

    final enabled = actions.toggleProvider(
      const [AiProviderType.openRouter],
      AiProviderType.groq,
      true,
    );
    final deduped = actions.toggleProvider(
      enabled,
      AiProviderType.groq,
      true,
    );
    final disabled = actions.toggleProvider(
      deduped,
      AiProviderType.openRouter,
      false,
    );

    expect(enabled, [AiProviderType.openRouter, AiProviderType.groq]);
    expect(deduped, [AiProviderType.openRouter, AiProviderType.groq]);
    expect(disabled, [AiProviderType.groq]);
  });
}

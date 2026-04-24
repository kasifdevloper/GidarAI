import '../../core/models/app_models.dart';

class ProviderRouter {
  const ProviderRouter();

  List<AiProviderType> resolveChain({
    required ChatRoutingMode routingMode,
    required ModelOption? selectedModel,
    required List<AiProviderType> enabledProviders,
  }) {
    final enabled = enabledProviders.isEmpty
        ? const [
            AiProviderType.openRouter,
            AiProviderType.groq,
            AiProviderType.gemini,
          ]
        : enabledProviders;
    final selectedProvider = selectedModel?.provider;

    final fallbackByMode = switch (routingMode) {
      ChatRoutingMode.autoFast => [
          AiProviderType.groq,
          AiProviderType.cerebras,
          AiProviderType.gemini,
          AiProviderType.zAi,
          AiProviderType.openRouter,
        ],
      ChatRoutingMode.autoSmart => [
          AiProviderType.gemini,
          AiProviderType.zAi,
          AiProviderType.groq,
          AiProviderType.cerebras,
          AiProviderType.openRouter,
        ],
      ChatRoutingMode.autoCoding => [
          if (selectedProvider != null) selectedProvider,
          AiProviderType.zAi,
          AiProviderType.cerebras,
          AiProviderType.groq,
          AiProviderType.gemini,
          AiProviderType.openRouter,
        ],
      ChatRoutingMode.autoVision => [
          AiProviderType.gemini,
          AiProviderType.zAi,
          AiProviderType.openRouter,
        ],
      ChatRoutingMode.directModel => [
          if (selectedProvider != null) selectedProvider,
        ],
    };

    final ordered = <AiProviderType>[];
    for (final provider in fallbackByMode) {
      if (!enabled.contains(provider) || ordered.contains(provider)) continue;
      ordered.add(provider);
    }
    if (ordered.isEmpty) {
      if (selectedProvider != null) {
        ordered.add(selectedProvider);
      }
    }
    return ordered;
  }
}

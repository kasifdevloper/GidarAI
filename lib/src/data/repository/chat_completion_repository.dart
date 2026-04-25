import 'dart:async';

import '../../core/models/app_descriptors.dart';
import '../../core/models/app_models.dart';
import '../remote/chat_provider_remote_data_source.dart';
import '../remote/cerebras_remote_data_source.dart';
import '../remote/custom_openai_remote_data_source.dart';
import '../remote/gemini_remote_data_source.dart';
import '../remote/groq_remote_data_source.dart';
import '../remote/mistral_remote_data_source.dart';
import '../remote/openrouter_remote_data_source.dart';
import '../remote/sambanova_remote_data_source.dart';
import '../remote/zai_remote_data_source.dart';
import 'provider_router.dart';

class ChatCompletionRepository {
  static const Map<AiProviderType, ModelOption> _probeModels = {
    AiProviderType.openRouter: ModelOption(
      name: 'OpenRouter Probe',
      id: 'openai/gpt-4o-mini',
      blurb: 'Probe model',
      provider: AiProviderType.openRouter,
    ),
    AiProviderType.groq: ModelOption(
      name: 'Groq Probe',
      id: 'llama-3.1-8b-instant',
      blurb: 'Probe model',
      provider: AiProviderType.groq,
    ),
    AiProviderType.gemini: ModelOption(
      name: 'Gemini Probe',
      id: 'gemini-1.5-flash',
      blurb: 'Probe model',
      provider: AiProviderType.gemini,
    ),
    AiProviderType.cerebras: ModelOption(
      name: 'Cerebras Probe',
      id: 'llama3.1-8b',
      blurb: 'Probe model',
      provider: AiProviderType.cerebras,
    ),
    AiProviderType.zAi: ModelOption(
      name: 'Z.ai Probe',
      id: 'glm-4.6',
      blurb: 'Probe model',
      provider: AiProviderType.zAi,
    ),
    AiProviderType.mistral: ModelOption(
      name: 'Mistral Probe',
      id: 'mistral-small-latest',
      blurb: 'Probe model',
      provider: AiProviderType.mistral,
    ),
    AiProviderType.sambanova: ModelOption(
      name: 'Sambanova Probe',
      id: 'Meta-Llama-3.1-8B-Instruct',
      blurb: 'Probe model',
      provider: AiProviderType.sambanova,
    ),
    AiProviderType.custom: ModelOption(
      name: 'Custom Probe',
      id: 'gpt-4o-mini',
      blurb: 'Probe model',
      provider: AiProviderType.custom,
    ),
  };

  ChatCompletionRepository({
    OpenRouterRemoteDataSource? openRouterRemoteDataSource,
    GroqRemoteDataSource? groqRemoteDataSource,
    GeminiRemoteDataSource? geminiRemoteDataSource,
    CerebrasRemoteDataSource? cerebrasRemoteDataSource,
    ZaiRemoteDataSource? zaiRemoteDataSource,
    MistralRemoteDataSource? mistralRemoteDataSource,
    SambanovaRemoteDataSource? sambanovaRemoteDataSource,
    CustomOpenAiRemoteDataSource? customOpenAiRemoteDataSource,
    ProviderRouter? providerRouter,
  })  : _providerRouter = providerRouter ?? const ProviderRouter(),
        _customOpenAiRemoteDataSource =
            customOpenAiRemoteDataSource ?? CustomOpenAiRemoteDataSource() {
    _providers = {
      AiProviderType.openRouter:
          openRouterRemoteDataSource ?? OpenRouterRemoteDataSource(),
      AiProviderType.groq: groqRemoteDataSource ?? GroqRemoteDataSource(),
      AiProviderType.gemini: geminiRemoteDataSource ?? GeminiRemoteDataSource(),
      AiProviderType.cerebras:
          cerebrasRemoteDataSource ?? CerebrasRemoteDataSource(),
      AiProviderType.zAi: zaiRemoteDataSource ?? ZaiRemoteDataSource(),
      AiProviderType.mistral:
          mistralRemoteDataSource ?? MistralRemoteDataSource(),
      AiProviderType.sambanova:
          sambanovaRemoteDataSource ?? SambanovaRemoteDataSource(),
      AiProviderType.custom: _customOpenAiRemoteDataSource,
    };
  }

  final ProviderRouter _providerRouter;
  final CustomOpenAiRemoteDataSource _customOpenAiRemoteDataSource;
  late final Map<AiProviderType, ChatProviderRemoteDataSource> _providers;

  static const int _maxRetries = 1;
  static const Duration _rateLimitRetryDelay = Duration(seconds: 3);
  static const Duration _timeoutRetryDelay = Duration(seconds: 2);

  void updateCustomProviderConfig(CustomProviderConfig config) {
    _customOpenAiRemoteDataSource.updateConfig(config);
  }

  Stream<String> streamChatCompletion({
    required ProviderKeys providerKeys,
    required List<CustomProviderConfig> customProviders,
    required ModelOption model,
    required ChatRoutingMode routingMode,
    required List<AiProviderType> enabledProviders,
    required String systemPrompt,
    required List<ChatMessage> history,
    void Function(AiProviderType provider, ModelOption model)?
        onProviderSelected,
    void Function(String message)? onProviderNotice,
  }) async* {
    final effectiveSystemPrompt = buildEffectiveSystemPrompt(systemPrompt);
    final chain = _providerRouter.resolveChain(
      routingMode: routingMode,
      selectedModel: model,
      enabledProviders: enabledProviders,
    );

    Object? lastError;
    for (var index = 0; index < chain.length; index++) {
      final providerType = chain[index];
      final remote = _providers[providerType];
      if (remote == null) continue;
      final customProvider = providerType == AiProviderType.custom
          ? findCustomProviderById(customProviders, model.customProviderId)
          : null;
      final apiKey = providerType == AiProviderType.custom
          ? (customProvider?.apiKey.trim() ?? '')
          : providerKeys.keyFor(providerType).trim();
      if (providerType == AiProviderType.custom) {
        if (customProvider == null) {
          lastError = const ProviderChatException(
            provider: AiProviderType.custom,
            message: 'Custom provider configuration is missing.',
          );
          continue;
        }
        _customOpenAiRemoteDataSource.updateConfig(customProvider);
      }
      if (apiKey.isEmpty) {
        lastError = ProviderChatException(
          provider: providerType,
          message: providerType == AiProviderType.custom
              ? 'Missing ${customProvider?.normalizedName ?? providerLabel(providerType)} API key.'
              : 'Missing ${providerLabel(providerType)} API key.',
        );
        continue;
      }

      final selectedModel = providerType == model.provider
          ? model
          : _fallbackModelFor(providerType, preferredModel: model);
      if (selectedModel == null) continue;

      for (var attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          if (attempt > 0) {
            onProviderNotice?.call(
              'Retrying ${providerLabel(providerType)}... (attempt ${attempt + 1})',
            );
          } else {
            onProviderSelected?.call(providerType, selectedModel);
            if (providerType != model.provider ||
                routingMode != ChatRoutingMode.directModel) {
              final providerRuntimeLabel = providerType == AiProviderType.custom
                  ? customProvider?.normalizedName ??
                      providerLabel(providerType)
                  : providerLabel(providerType);
              onProviderNotice?.call(
                'Using $providerRuntimeLabel • ${selectedModel.name}',
              );
            }
          }
          yield* remote.streamChatCompletion(
            apiKey: apiKey,
            model: selectedModel,
            systemPrompt: effectiveSystemPrompt,
            history: history,
          );
          return;
        } catch (error) {
          lastError = error;
          final isRateLimit = _isRateLimitError(error);
          final isTimeout = _isTimeoutError(error);

          if (isRateLimit && attempt < _maxRetries) {
            await Future<void>.delayed(_rateLimitRetryDelay);
            continue;
          }
          if (isTimeout && attempt < _maxRetries) {
            await Future<void>.delayed(_timeoutRetryDelay);
            continue;
          }

          if (index < chain.length - 1) {
            final nextProvider = chain[index + 1];
            onProviderNotice?.call(
              'Switching from ${providerLabel(providerType)} to ${providerLabel(nextProvider)}',
            );
          }
          break;
        }
      }
    }

    throw lastError ??
        const ProviderChatException(
          provider: AiProviderType.openRouter,
          message: 'No enabled provider could handle this request.',
        );
  }

  bool _isRateLimitError(Object error) {
    if (error is ProviderChatException) {
      return error.message.toLowerCase().contains('rate limit');
    }
    final text = error.toString().toLowerCase();
    return text.contains('rate limit') || text.contains('429');
  }

  bool _isTimeoutError(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('timeout') || text.contains('timed out');
  }

  Future<void> validateProviderKey({
    required AiProviderType provider,
    required String apiKey,
    CustomProviderConfig? customProvider,
  }) async {
    if (provider == AiProviderType.custom) {
      if (customProvider == null) {
        throw const ProviderChatException(
          provider: AiProviderType.custom,
          message: 'Custom provider configuration is missing.',
        );
      }
      _customOpenAiRemoteDataSource.updateConfig(customProvider);
      final models =
          await _customOpenAiRemoteDataSource.fetchModels(apiKey: apiKey);
      if (models.isEmpty) {
        throw const ProviderChatException(
          provider: AiProviderType.custom,
          message: 'Custom provider returned no models.',
        );
      }
      return;
    }

    final remote = _providers[provider];
    if (remote == null) {
      throw ProviderChatException(
        provider: provider,
        message: '${providerLabel(provider)} is not configured yet.',
      );
    }

    final model = _probeModels[provider];
    if (model == null) {
      throw ProviderChatException(
        provider: provider,
        message: 'No test model available for ${providerLabel(provider)}.',
      );
    }

    final probeMessage = ChatMessage(
      id: 'probe',
      role: 'user',
      content: 'Reply with OK only.',
      createdAt: DateTime.now(),
    );

    final firstChunk = await remote
        .streamChatCompletion(
          apiKey: apiKey,
          model: model,
          systemPrompt: 'You are a concise assistant.',
          history: [probeMessage],
        )
        .timeout(const Duration(seconds: 20))
        .first;

    if (firstChunk.trim().isEmpty) {
      throw ProviderChatException(
        provider: provider,
        message:
            '${providerLabel(provider)} returned an empty validation response.',
      );
    }
  }

  void dispose() {
    for (final provider in _providers.values) {
      provider.dispose();
    }
  }

  ModelOption? _fallbackModelFor(
    AiProviderType providerType, {
    required ModelOption preferredModel,
  }) {
    if (providerType == preferredModel.provider) {
      return preferredModel;
    }
    if (providerType == AiProviderType.custom) {
      return null;
    }
    return _probeModels[providerType];
  }
}

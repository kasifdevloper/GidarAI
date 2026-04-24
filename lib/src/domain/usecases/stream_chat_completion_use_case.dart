import '../../core/models/app_models.dart';
import '../../data/repository/chat_completion_repository.dart';

class StreamChatCompletionUseCase {
  StreamChatCompletionUseCase(this._repository);

  final ChatCompletionRepository _repository;

  Stream<String> call({
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
  }) {
    return _repository.streamChatCompletion(
      providerKeys: providerKeys,
      customProviders: customProviders,
      model: model,
      routingMode: routingMode,
      enabledProviders: enabledProviders,
      systemPrompt: systemPrompt,
      history: history,
      onProviderSelected: onProviderSelected,
      onProviderNotice: onProviderNotice,
    );
  }
}

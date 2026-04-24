import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';
import 'groq_remote_data_source.dart';

class OpenRouterModel {
  final String id;
  final String name;
  final String description;
  final int? contextLength;
  final bool supportsVision;
  final String? inputPrice;
  final String? outputPrice;

  OpenRouterModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.supportsVision = false,
    this.inputPrice,
    this.outputPrice,
  });

  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    return OpenRouterModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
      contextLength: json['context_length'] as int?,
      supportsVision: (json['architecture'] as Map<String, dynamic>?)?['modality']
              ?.toString()
              .contains('image') ??
          false,
      inputPrice: pricing?['prompt'] as String?,
      outputPrice: pricing?['completion'] as String?,
    );
  }
}

class OpenRouterRemoteDataSource implements ChatProviderRemoteDataSource {
  OpenRouterRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  http.Client _client;
  static final Uri _endpoint =
      Uri.parse('https://openrouter.ai/api/v1/chat/completions');

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.openRouter;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.openRouter,
        message: 'Please add your OpenRouter API key in Settings.',
      );
    }

    _client.close();
    _client = http.Client();

    final request = http.Request('POST', _endpoint)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://gidar.ai',
        'X-Title': 'Gidar AI',
      })
      ..body = jsonEncode({
        'model': model.id,
        'stream': true,
        'route': 'fallback',
        'messages': [
          if (systemPrompt.trim().isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          ...history.takeLast(20).map((message) => {
                'role': message.role,
                'content': message.toOpenAiCompatibleContent(
                  supportsVision: model.supportsVision,
                ),
              }),
        ],
      });

    final response = await _client.send(request).timeout(_connectionTimeout);
    if (response.statusCode == 401) {
      throw const ProviderChatException(
        provider: AiProviderType.openRouter,
        message: 'Invalid OpenRouter API key',
      );
    }
    if (response.statusCode == 429) {
      throw const ProviderChatException(
        provider: AiProviderType.openRouter,
        message: 'OpenRouter rate limit exceeded',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ProviderChatException(
        provider: AiProviderType.openRouter,
        message:
        errorBody.isEmpty
            ? 'OpenRouter error ${response.statusCode}'
            : 'OpenRouter error ${response.statusCode}: $errorBody',
      );
    }

    try {
      yield* parseOpenAiCompatibleSse(response.stream);
    } finally {
      _client.close();
      _client = http.Client();
    }
  }

  @override
  void dispose() {
    _client.close();
  }

  Future<List<OpenRouterModel>> fetchModels({String? apiKey}) async {
    final uri = Uri.parse('https://openrouter.ai/api/v1/models');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    } else {
      throw Exception('OpenRouter API key is required to fetch models. Please add your API key in Settings.');
    }

    final response = await _client.get(uri, headers: headers);
    
    if (response.statusCode == 401) {
      throw Exception('Invalid OpenRouter API key. Please check your API key in Settings.');
    }
    if (response.statusCode == 403) {
      throw Exception('OpenRouter API access forbidden. Your API key may not have permission to list models.');
    }
    if (response.statusCode == 429) {
      throw Exception('OpenRouter rate limit exceeded. Please wait a moment and try again.');
    }
    if (response.statusCode != 200) {
      final errorBody = response.body;
      throw Exception('OpenRouter API error ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Unknown error"}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>;
    
    return models
        .map((model) => OpenRouterModel.fromJson(model as Map<String, dynamic>))
        .toList();
  }
}

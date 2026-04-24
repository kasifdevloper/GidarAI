import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';
import 'groq_remote_data_source.dart';

class MistralRemoteDataSource implements ChatProviderRemoteDataSource {
  MistralRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  http.Client _client;
  static final Uri _endpoint =
      Uri.parse('https://api.mistral.ai/v1/chat/completions');

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.mistral;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.mistral,
        message: 'Please add your Mistral API key in Settings.',
      );
    }

    _client.close();
    _client = http.Client();

    final request = http.Request('POST', _endpoint)
      ..headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'model': model.id,
        'stream': true,
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
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ProviderChatException(
        provider: AiProviderType.mistral,
        message: 'Invalid Mistral API key',
      );
    }
    if (response.statusCode == 429) {
      throw const ProviderChatException(
        provider: AiProviderType.mistral,
        message: 'Mistral rate limit exceeded',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ProviderChatException(
        provider: AiProviderType.mistral,
        message: errorBody.isEmpty
            ? 'Mistral error ${response.statusCode}'
            : 'Mistral error ${response.statusCode}: $errorBody',
      );
    }

    try {
      yield* parseOpenAiCompatibleSse(response.stream);
    } finally {
      _client.close();
      _client = http.Client();
    }
  }

  Future<List<MistralModel>> fetchModels({required String apiKey}) async {
    final uri = Uri.parse('https://api.mistral.ai/v1/models');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Invalid Mistral API key. Please check your API key in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw Exception('Mistral rate limit exceeded. Please wait and try again.');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Mistral API error ${response.statusCode}: ${response.body.isEmpty ? "Unknown error" : response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>? ?? const [];
    return models
        .map((item) => MistralModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  void dispose() {
    _client.close();
  }
}

class MistralModel {
  const MistralModel({
    required this.id,
    required this.name,
    required this.description,
    required this.visionSupport,
    this.contextLength,
    this.maxOutputTokens,
  });

  final String id;
  final String name;
  final String description;
  final ModelVisionSupport visionSupport;
  final int? contextLength;
  final int? maxOutputTokens;

  factory MistralModel.fromJson(Map<String, dynamic> json) {
    final capabilities = json['capabilities'] as Map<String, dynamic>?;
    final visionFlag = capabilities?['vision'] == true ||
        capabilities?['image_input'] == true ||
        (json['modalities'] as List<dynamic>? ?? const [])
            .map((value) => value.toString().toLowerCase())
            .contains('image');

    return MistralModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
      visionSupport: visionFlag
          ? ModelVisionSupport.supported
          : ModelVisionSupport.unknown,
      contextLength: json['context_length'] as int? ?? json['max_context_length'] as int?,
      maxOutputTokens: json['max_output_tokens'] as int?,
    );
  }
}

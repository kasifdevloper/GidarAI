import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';
import 'groq_remote_data_source.dart';

class SambanovaRemoteDataSource implements ChatProviderRemoteDataSource {
  SambanovaRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  http.Client _client;
  static final Uri _endpoint =
      Uri.parse('https://api.sambanova.ai/v1/chat/completions');

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.sambanova;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.sambanova,
        message: 'Please add your Sambanova API key in Settings.',
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
        provider: AiProviderType.sambanova,
        message: 'Invalid Sambanova API key',
      );
    }
    if (response.statusCode == 429) {
      throw const ProviderChatException(
        provider: AiProviderType.sambanova,
        message: 'Sambanova rate limit exceeded',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ProviderChatException(
        provider: AiProviderType.sambanova,
        message: errorBody.isEmpty
            ? 'Sambanova error ${response.statusCode}'
            : 'Sambanova error ${response.statusCode}: $errorBody',
      );
    }

    try {
      yield* parseOpenAiCompatibleSse(response.stream);
    } finally {
      _client.close();
      _client = http.Client();
    }
  }

  Future<List<SambanovaModel>> fetchModels({required String apiKey}) async {
    final uri = Uri.parse('https://api.sambanova.ai/v1/models');
    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Invalid Sambanova API key. Please check your API key in Settings.',
      );
    }
    if (response.statusCode == 429) {
      throw Exception(
        'Sambanova rate limit exceeded. Please wait and try again.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Sambanova API error ${response.statusCode}: ${response.body.isEmpty ? "Unknown error" : response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>? ?? const [];
    return models
        .map((item) =>
            SambanovaModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  void dispose() {
    _client.close();
  }
}

class SambanovaModel {
  const SambanovaModel({
    required this.id,
    required this.name,
    required this.description,
    required this.visionSupport,
    this.contextLength,
    this.maxOutputTokens,
    this.inputPrice,
    this.outputPrice,
  });

  final String id;
  final String name;
  final String description;
  final ModelVisionSupport visionSupport;
  final int? contextLength;
  final int? maxOutputTokens;
  final String? inputPrice;
  final String? outputPrice;

  factory SambanovaModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    final modalities = (json['modalities'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().toLowerCase())
        .toList();
    final supportsVision = modalities.contains('image') ||
        modalities.contains('vision') ||
        ((json['capabilities'] as Map<String, dynamic>?)?['vision'] == true);

    return SambanovaModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? json['id'] as String,
      description: json['description'] as String? ?? '',
      visionSupport: supportsVision
          ? ModelVisionSupport.supported
          : ModelVisionSupport.unknown,
      contextLength: json['context_length'] as int? ?? json['context_window'] as int?,
      maxOutputTokens: json['max_output_tokens'] as int?,
      inputPrice: pricing?['prompt']?.toString(),
      outputPrice: pricing?['completion']?.toString(),
    );
  }
}

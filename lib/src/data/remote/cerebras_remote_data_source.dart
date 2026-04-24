import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';
import 'groq_remote_data_source.dart';

class CerebrasRemoteDataSource implements ChatProviderRemoteDataSource {
  CerebrasRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  http.Client _client;
  static final Uri _endpoint =
      Uri.parse('https://api.cerebras.ai/v1/chat/completions');

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.cerebras;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.cerebras,
        message: 'Please add your Cerebras API key in Settings.',
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
                'content': message.toPlainTextPrompt(),
              }),
        ],
      });

    final response = await _client.send(request).timeout(_connectionTimeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ProviderChatException(
        provider: AiProviderType.cerebras,
        message: 'Invalid Cerebras API key',
      );
    }
    if (response.statusCode == 429) {
      throw const ProviderChatException(
        provider: AiProviderType.cerebras,
        message: 'Cerebras rate limit exceeded',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ProviderChatException(
        provider: AiProviderType.cerebras,
        message: errorBody.isEmpty
            ? 'Cerebras error ${response.statusCode}'
            : 'Cerebras error ${response.statusCode}: $errorBody',
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

  Future<List<CerebrasModel>> fetchModels({required String apiKey}) async {
    final uri = Uri.parse('https://api.cerebras.ai/v1/models');
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final response = await _client.get(uri, headers: headers);
    
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Invalid Cerebras API key. Please check your API key in Settings.');
    }
    if (response.statusCode == 429) {
      throw Exception('Cerebras rate limit exceeded. Please wait a moment and try again.');
    }
    if (response.statusCode != 200) {
      final errorBody = response.body;
      throw Exception('Cerebras API error ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Unknown error"}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>;
    
    return models
        .map((model) => CerebrasModel.fromJson(model as Map<String, dynamic>))
        .toList();
  }
}

class CerebrasModel {
  final String id;
  final String name;
  final String description;
  final int? contextLength;
  final bool supportsVision;

  CerebrasModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.supportsVision = false,
  });

  factory CerebrasModel.fromJson(Map<String, dynamic> json) {
    return CerebrasModel(
      id: json['id'] as String,
      name: json['id'] as String,
      description: json['description'] as String? ?? '',
      contextLength: json['context_length'] as int?,
      supportsVision: false,
    );
  }
}

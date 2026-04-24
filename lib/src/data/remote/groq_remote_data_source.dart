import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';

class GroqRemoteDataSource implements ChatProviderRemoteDataSource {
  GroqRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  http.Client _client;
  static final Uri _endpoint =
      Uri.parse('https://api.groq.com/openai/v1/chat/completions');

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.groq;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.groq,
        message: 'Please add your Groq API key in Settings.',
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
    if (response.statusCode == 401) {
      throw const ProviderChatException(
        provider: AiProviderType.groq,
        message: 'Invalid Groq API key',
      );
    }
    if (response.statusCode == 429) {
      throw const ProviderChatException(
        provider: AiProviderType.groq,
        message: 'Groq rate limit exceeded',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ProviderChatException(
        provider: AiProviderType.groq,
        message: errorBody.isEmpty
            ? 'Groq error ${response.statusCode}'
            : 'Groq error ${response.statusCode}: $errorBody',
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

  Future<List<GroqModel>> fetchModels({required String apiKey}) async {
    final uri = Uri.parse('https://api.groq.com/openai/v1/models');
    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final response = await _client.get(uri, headers: headers);
    
    if (response.statusCode == 401) {
      throw Exception('Invalid Groq API key. Please check your API key in Settings.');
    }
    if (response.statusCode == 403) {
      throw Exception('Groq API access forbidden. Your API key may not have permission to list models.');
    }
    if (response.statusCode == 429) {
      throw Exception('Groq rate limit exceeded. Please wait a moment and try again.');
    }
    if (response.statusCode != 200) {
      final errorBody = response.body;
      throw Exception('Groq API error ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Unknown error"}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List<dynamic>;
    
    return models
        .map((model) => GroqModel.fromJson(model as Map<String, dynamic>))
        .toList();
  }
}

class GroqModel {
  final String id;
  final String name;
  final String description;
  final int? contextLength;
  final bool supportsVision;

  GroqModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.supportsVision = false,
  });

  factory GroqModel.fromJson(Map<String, dynamic> json) {
    return GroqModel(
      id: json['id'] as String,
      name: json['id'] as String,
      description: json['description'] as String? ?? '',
      contextLength: json['context_window'] as int?,
      supportsVision: false,
    );
  }
}

Stream<String> parseOpenAiCompatibleSse(Stream<List<int>> byteStream) async* {
  var buffer = '';
  await for (final chunk in byteStream.transform(utf8.decoder)) {
    buffer += chunk;
    final lines = buffer.split('\n');
    buffer = lines.removeLast();
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') return;
      try {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>? ?? const [];
        if (choices.isEmpty) continue;
        final choice = Map<String, dynamic>.from(choices.first as Map);
        final delta = choice['delta'] as Map<String, dynamic>? ?? const {};
        final content = extractProviderAnswerText(delta['content']) ??
            extractProviderAnswerText(choice['message'] is Map<String, dynamic>
                ? (choice['message'] as Map<String, dynamic>)['content']
                : null) ??
            extractProviderAnswerText(choice['text']);
        if (content != null && content.isNotEmpty) {
          yield content;
        }
        final finishReason = choice['finish_reason'];
        if (finishReason != null &&
            '$finishReason'.trim().isNotEmpty &&
            '$finishReason'.trim() != 'null') {
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }
}

String? extractProviderAnswerText(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (value is List) {
    final buffer = StringBuffer();
    for (final item in value) {
      if (item is Map) {
        final normalized = Map<String, dynamic>.from(item);
        if (_isReasoningChunk(normalized)) {
          continue;
        }
        final text = _extractChunkText(normalized);
        if (text != null && text.isNotEmpty) {
          buffer.write(text);
        }
      }
    }
    final normalized = buffer.toString();
    return normalized.isEmpty ? null : normalized;
  }
  return null;
}

bool _isReasoningChunk(Map<String, dynamic> value) {
  if (value['thought'] == true) {
    return true;
  }
  final type = value['type']?.toString().toLowerCase() ?? '';
  if (type.contains('thinking') || type.contains('reasoning') || type == 'thought') {
    return true;
  }
  return value.containsKey('thinking') ||
      value.containsKey('reasoning') ||
      value.containsKey('summary');
}

String? _extractChunkText(Map<String, dynamic> value) {
  final directText = value['text'];
  if (directText is String && directText.isNotEmpty) {
    return directText;
  }
  for (final key in const ['thinking', 'reasoning', 'summary', 'content']) {
    final nested = value[key];
    final text = _extractStructuredText(nested);
    if (text != null && text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String? _extractStructuredText(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  if (value is List) {
    final buffer = StringBuffer();
    for (final item in value) {
      if (item is String && item.isNotEmpty) {
        buffer.write(item);
        continue;
      }
      if (item is Map) {
        final text = _extractChunkText(Map<String, dynamic>.from(item));
        if (text != null && text.isNotEmpty) {
          buffer.write(text);
        }
      }
    }
    final normalized = buffer.toString();
    return normalized.isEmpty ? null : normalized;
  }
  if (value is Map) {
    return _extractChunkText(Map<String, dynamic>.from(value));
  }
  return null;
}

class ProviderChatException implements Exception {
  const ProviderChatException({
    required this.provider,
    required this.message,
  });

  final AiProviderType provider;
  final String message;

  @override
  String toString() => message;
}

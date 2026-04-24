import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';
import 'groq_remote_data_source.dart';

class GeminiRemoteDataSource implements ChatProviderRemoteDataSource {
  GeminiRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  http.Client _client;
  final bool _ownsClient;

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.gemini;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.gemini,
        message: 'Please add your Gemini API key in Settings.',
      );
    }

    if (_ownsClient) {
      _client.close();
      _client = http.Client();
    }

    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${model.id}:streamGenerateContent?alt=sse&key=$apiKey',
    );

    final request = http.Request('POST', endpoint)
      ..headers.addAll({
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        if (systemPrompt.trim().isNotEmpty)
          'system_instruction': {
            'parts': [
              {'text': systemPrompt},
            ],
          },
        'contents': history
            .takeLast(20)
            .map((message) => message.toGeminiContent(
                  supportsVision: model.supportsVision,
                ))
            .toList(),
      });

    final response = await _client.send(request).timeout(_connectionTimeout);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ProviderChatException(
        provider: AiProviderType.gemini,
        message: 'Invalid Gemini API key',
      );
    }
    if (response.statusCode == 429) {
      throw const ProviderChatException(
        provider: AiProviderType.gemini,
        message: 'Gemini rate limit exceeded',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ProviderChatException(
        provider: AiProviderType.gemini,
        message: errorBody.isEmpty
            ? 'Gemini error ${response.statusCode}'
            : 'Gemini error ${response.statusCode}: $errorBody',
      );
    }

    try {
      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data.isEmpty || data == '[DONE]') continue;
          try {
            final decoded = jsonDecode(data) as Map<String, dynamic>;
            final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
            if (candidates.isEmpty) continue;
            final candidate = Map<String, dynamic>.from(candidates.first as Map);
            final content = candidate['content'] as Map<String, dynamic>? ?? const {};
            final parts = content['parts'] as List<dynamic>? ?? const [];
            for (final part in parts) {
              if (part is! Map) continue;
              final normalizedPart = Map<String, dynamic>.from(part);
              if (normalizedPart['thought'] == true) {
                continue;
              }
              final text = normalizedPart['text'];
              if (text is String && text.isNotEmpty) {
                for (final chunk in _splitGeminiAnswerForStreaming(text)) {
                  yield chunk;
                }
              }
            }
            final finishReason = candidate['finishReason'];
            if (finishReason != null && '$finishReason'.isNotEmpty) {
              return;
            }
          } catch (_) {
            continue;
          }
        }
      }
    } finally {
      if (_ownsClient) {
        _client.close();
        _client = http.Client();
      }
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<List<GeminiModel>> fetchModels({required String apiKey}) async {
    final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final response = await _client.get(uri, headers: headers);
    
    if (response.statusCode == 400) {
      throw Exception('Invalid Gemini API key format. Please check your API key in Settings.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Invalid Gemini API key. Please check your API key in Settings.');
    }
    if (response.statusCode == 429) {
      throw Exception('Gemini rate limit exceeded. Please wait a moment and try again.');
    }
    if (response.statusCode != 200) {
      final errorBody = response.body;
      throw Exception('Gemini API error ${response.statusCode}: ${errorBody.isNotEmpty ? errorBody : "Unknown error"}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List<dynamic>;
    
    return models
        .map((model) => GeminiModel.fromJson(model as Map<String, dynamic>))
        .toList();
  }
}

Iterable<String> _splitGeminiAnswerForStreaming(String text) sync* {
  if (text.length <= 320) {
    yield text;
    return;
  }

  final paragraphs = _splitTextWithDelimiter(
    text,
    RegExp(r'.*?(?:\n\s*\n|$)', dotAll: true),
  );
  if (paragraphs.length <= 1) {
    yield* _splitGeminiParagraph(text);
    return;
  }

  for (final paragraph in paragraphs) {
    if (paragraph.trim().isEmpty) {
      continue;
    }
    if (paragraph.length <= 320) {
      yield paragraph;
      continue;
    }
    yield* _splitGeminiParagraph(paragraph);
  }
}

Iterable<String> _splitGeminiParagraph(String text) sync* {
  final sentences = _splitTextWithDelimiter(
    text,
    RegExp(r'.*?(?:[.!?।](?:\s+|$)|\n|$)', dotAll: true),
  );
  if (sentences.length <= 1) {
    yield* _splitGeminiByLength(text);
    return;
  }

  final buffer = StringBuffer();
  for (final sentence in sentences) {
    if (sentence.isEmpty) {
      continue;
    }
    if (buffer.isNotEmpty &&
        buffer.length + sentence.length > 260 &&
        buffer.length >= 120) {
      yield buffer.toString();
      buffer.clear();
    }
    if (sentence.length > 320) {
      if (buffer.isNotEmpty) {
        yield buffer.toString();
        buffer.clear();
      }
      yield* _splitGeminiByLength(sentence);
      continue;
    }
    buffer.write(sentence);
  }

  if (buffer.isNotEmpty) {
    yield buffer.toString();
  }
}

Iterable<String> _splitGeminiByLength(String text) sync* {
  var remaining = text;
  while (remaining.length > 320) {
    var splitAt = remaining.lastIndexOf(' ', 240);
    if (splitAt < 120) {
      splitAt = remaining.lastIndexOf('\n', 240);
    }
    if (splitAt < 120) {
      splitAt = 240;
    }
    yield remaining.substring(0, splitAt);
    remaining = remaining.substring(splitAt);
  }
  if (remaining.isNotEmpty) {
    yield remaining;
  }
}

List<String> _splitTextWithDelimiter(String text, RegExp pattern) {
  final matches = pattern
      .allMatches(text)
      .map((match) => match.group(0) ?? '')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return matches.isEmpty ? [text] : matches;
}

class GeminiModel {
  final String id;
  final String name;
  final String description;
  final int? contextLength;
  final int? outputTokenLimit;
  final bool supportsVision;

  GeminiModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.outputTokenLimit,
    this.supportsVision = false,
  });

  factory GeminiModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final id = name.contains('/') ? name.split('/').last : name;
    final supportedGenerationMethods = json['supportedGenerationMethods'] as List<dynamic>? ?? [];
    final inputTokenLimit = json['inputTokenLimit'] as int?;
    final outputTokenLimit = json['outputTokenLimit'] as int?;
    
    return GeminiModel(
      id: id,
      name: json['displayName'] as String? ?? id,
      description: json['description'] as String? ?? '',
      contextLength: inputTokenLimit,
      outputTokenLimit: outputTokenLimit,
      supportsVision: supportedGenerationMethods.contains('generateContent'),
    );
  }
}

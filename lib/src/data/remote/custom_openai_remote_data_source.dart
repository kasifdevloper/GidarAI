import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/models/app_models.dart';
import 'chat_provider_remote_data_source.dart';
import 'groq_remote_data_source.dart';

class CustomOpenAiModel {
  const CustomOpenAiModel({
    required this.id,
    required this.name,
    required this.description,
    this.contextLength,
    this.supportsVision = false,
  });

  final String id;
  final String name;
  final String description;
  final int? contextLength;
  final bool supportsVision;

  factory CustomOpenAiModel.fromJson(Map<String, dynamic> json) {
    final modalities = (json['modalities'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().toLowerCase())
        .toList();
    final architecture = json['architecture'] as Map<String, dynamic>?;
    final modality = architecture?['modality']?.toString().toLowerCase() ?? '';
    final supportsVision = modalities.any((value) => value.contains('image')) ||
        modality.contains('image') ||
        modality.contains('vision');
    return CustomOpenAiModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? 'Custom Model',
      description:
          json['description'] as String? ?? json['owned_by'] as String? ?? '',
      contextLength:
          json['context_length'] as int? ?? json['context_window'] as int?,
      supportsVision: supportsVision,
    );
  }
}

class CustomOpenAiRemoteDataSource implements ChatProviderRemoteDataSource {
  CustomOpenAiRemoteDataSource({
    http.Client? client,
    CustomProviderConfig config = const CustomProviderConfig(),
  })  : _client = client ?? http.Client(),
        _config = config;

  http.Client _client;
  CustomProviderConfig _config;

  static const Duration _connectionTimeout = Duration(seconds: 15);

  @override
  AiProviderType get provider => AiProviderType.custom;

  void updateConfig(CustomProviderConfig config) {
    _config = config;
  }

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) async* {
    _ensureConfigured();
    if (apiKey.trim().isEmpty) {
      throw const ProviderChatException(
        provider: AiProviderType.custom,
        message: 'Please add your custom provider API key in Settings.',
      );
    }

    _client.close();
    _client = http.Client();

    final request = http.Request('POST', _chatCompletionsEndpoint)
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
    await _throwIfInvalidResponse(
      response.statusCode,
      readBody: response.stream.bytesToString,
    );

    try {
      yield* parseOpenAiCompatibleSse(response.stream);
    } finally {
      _client.close();
      _client = http.Client();
    }
  }

  Future<List<CustomOpenAiModel>> fetchModels({required String apiKey}) async {
    _ensureConfigured();
    final response = await _client.get(
      _modelsEndpoint,
      headers: <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
    );
    await _throwIfInvalidResponse(
      response.statusCode,
      readBody: () async => response.body,
    );
    final decoded = jsonDecode(response.body);
    final rawModels = decoded is Map<String, dynamic>
        ? decoded['data'] as List<dynamic>? ?? const <dynamic>[]
        : decoded is List
            ? decoded
            : const <dynamic>[];
    return rawModels
        .map((item) =>
            CustomOpenAiModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((model) => model.id.trim().isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _client.close();
  }

  Uri get _chatCompletionsEndpoint =>
      Uri.parse('${_config.normalizedBaseUrl}/chat/completions');

  Uri get _modelsEndpoint => Uri.parse('${_config.normalizedBaseUrl}/models');

  String get _displayName => _config.normalizedName;

  void _ensureConfigured() {
    if (!_config.hasBaseUrl) {
      throw const ProviderChatException(
        provider: AiProviderType.custom,
        message: 'Please add your custom provider base URL in Settings.',
      );
    }
  }

  Future<void> _throwIfInvalidResponse(
    int statusCode, {
    Future<String> Function()? readBody,
  }) async {
    if (statusCode == 401) {
      throw ProviderChatException(
        provider: AiProviderType.custom,
        message: 'Invalid $_displayName API key',
      );
    }
    if (statusCode == 403) {
      throw ProviderChatException(
        provider: AiProviderType.custom,
        message: '$_displayName access forbidden',
      );
    }
    if (statusCode == 404) {
      throw ProviderChatException(
        provider: AiProviderType.custom,
        message: '$_displayName endpoint not found',
      );
    }
    if (statusCode == 429) {
      throw ProviderChatException(
        provider: AiProviderType.custom,
        message: '$_displayName rate limit exceeded',
      );
    }
    if (statusCode >= 200 && statusCode < 300) {
      return;
    }
    final errorBody = readBody == null ? '' : await readBody();
    throw ProviderChatException(
      provider: AiProviderType.custom,
      message: errorBody.isEmpty
          ? '$_displayName error $statusCode'
          : '$_displayName error $statusCode: $errorBody',
    );
  }
}

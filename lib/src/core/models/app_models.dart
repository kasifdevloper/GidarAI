import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

enum AppThemeMode {
  classicDark,
  pureLight,
  midnightBlue,
  forestGreen,
  sunsetPurple,
  roseGold,
  oceanTeal,
}

enum AppAppearanceMode {
  dark,
  light,
  system,
}

enum ChatColorMode {
  theme,
  colorful,
}

enum MessageFeedback {
  up,
  down,
}

enum AiProviderType {
  openRouter,
  groq,
  gemini,
  cerebras,
  zAi,
  mistral,
  sambanova,
  custom,
}

enum ChatRoutingMode {
  directModel,
  autoFast,
  autoSmart,
  autoCoding,
  autoVision,
}

enum UiDensityMode {
  compact,
  balanced,
}

enum AppFontPreset {
  systemDynamic,
  roboto,
  inter,
  manrope,
  urbanist,
  plusJakartaSans,
  sora,
  outfit,
  lexend,
  workSans,
  spaceGrotesk,
  poppins,
  nunito,
  openSans,
  dmSans,
  sourceSans3,
  rubik,
  ibmPlexSans,
  lora,
  hind,
  mukta,
  baloo2,
  martelSans,
  kalam,
  tiroDevanagariHindi,
  notoSansDevanagari,
  notoSerifDevanagari,
}

enum SettingsSection {
  overview,
  providers,
  models,
  systemPrompt,
  appearance,
  chatData,
  about,
}

enum ModelCategory {
  recommended,
  fast,
  smart,
  coding,
  vision,
  all,
}

enum ModelVisionSupport {
  supported,
  unsupported,
  unknown,
}

enum ProviderCheckState {
  idle,
  testing,
  success,
  failure,
}

class ProviderCheckStatus {
  const ProviderCheckStatus({
    this.state = ProviderCheckState.idle,
    this.message,
  });

  final ProviderCheckState state;
  final String? message;
}

class ProviderHealthSummary {
  const ProviderHealthSummary({
    required this.provider,
    required this.hasKey,
    required this.enabled,
    required this.status,
    required this.label,
    required this.note,
  });

  final AiProviderType provider;
  final bool hasKey;
  final bool enabled;
  final ProviderCheckStatus status;
  final String label;
  final String note;
}

class ProviderKeys {
  const ProviderKeys({
    this.openRouter = '',
    this.groq = '',
    this.gemini = '',
    this.cerebras = '',
    this.zAi = '',
    this.mistral = '',
    this.sambanova = '',
    this.custom = '',
  });

  final String openRouter;
  final String groq;
  final String gemini;
  final String cerebras;
  final String zAi;
  final String mistral;
  final String sambanova;
  final String custom;

  String keyFor(AiProviderType provider) {
    return switch (provider) {
      AiProviderType.openRouter => openRouter,
      AiProviderType.groq => groq,
      AiProviderType.gemini => gemini,
      AiProviderType.cerebras => cerebras,
      AiProviderType.zAi => zAi,
      AiProviderType.mistral => mistral,
      AiProviderType.sambanova => sambanova,
      AiProviderType.custom => custom,
    };
  }

  ProviderKeys copyWith({
    String? openRouter,
    String? groq,
    String? gemini,
    String? cerebras,
    String? zAi,
    String? mistral,
    String? sambanova,
    String? custom,
  }) {
    return ProviderKeys(
      openRouter: openRouter ?? this.openRouter,
      groq: groq ?? this.groq,
      gemini: gemini ?? this.gemini,
      cerebras: cerebras ?? this.cerebras,
      zAi: zAi ?? this.zAi,
      mistral: mistral ?? this.mistral,
      sambanova: sambanova ?? this.sambanova,
      custom: custom ?? this.custom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'openRouter': openRouter,
      'groq': groq,
      'gemini': gemini,
      'cerebras': cerebras,
      'zAi': zAi,
      'mistral': mistral,
      'sambanova': sambanova,
      'custom': custom,
    };
  }

  factory ProviderKeys.fromMap(Map<String, dynamic> map) {
    return ProviderKeys(
      openRouter: map['openRouter'] as String? ?? '',
      groq: map['groq'] as String? ?? '',
      gemini: map['gemini'] as String? ?? '',
      cerebras: map['cerebras'] as String? ?? '',
      zAi: map['zAi'] as String? ?? '',
      mistral: map['mistral'] as String? ?? '',
      sambanova: map['sambanova'] as String? ?? '',
      custom: map['custom'] as String? ?? '',
    );
  }
}

class CustomProviderConfig {
  const CustomProviderConfig({
    this.id = '',
    this.name = '',
    this.baseUrl = '',
    this.apiKey = '',
    this.enabled = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final bool enabled;

  String get normalizedName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Custom' : trimmed;
  }

  String get normalizedBaseUrl {
    var normalized = baseUrl.trim();
    if (normalized.isEmpty) return '';
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    const modelsSuffix = '/models';
    const chatSuffix = '/chat/completions';
    if (normalized.endsWith(modelsSuffix)) {
      normalized =
          normalized.substring(0, normalized.length - modelsSuffix.length);
    }
    if (normalized.endsWith(chatSuffix)) {
      normalized =
          normalized.substring(0, normalized.length - chatSuffix.length);
    }
    return normalized.replaceAll(RegExp(r'/+$'), '');
  }

  bool get hasName => name.trim().isNotEmpty;
  bool get hasBaseUrl => normalizedBaseUrl.isNotEmpty;
  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get hasAnyData => hasName || hasBaseUrl || hasApiKey;

  CustomProviderConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    bool? enabled,
  }) {
    return CustomProviderConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.trim(),
      'name': name.trim(),
      'baseUrl': normalizedBaseUrl,
      'apiKey': apiKey.trim(),
      'enabled': enabled,
    };
  }

  factory CustomProviderConfig.fromMap(Map<String, dynamic> map) {
    return CustomProviderConfig(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      baseUrl: map['baseUrl'] as String? ?? '',
      apiKey: map['apiKey'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? false,
    );
  }
}

CustomProviderConfig? findCustomProviderById(
  Iterable<CustomProviderConfig> providers,
  String? id,
) {
  if (id == null || id.trim().isEmpty) return null;
  final normalizedId = id.trim();
  for (final provider in providers) {
    if (provider.id == normalizedId) {
      return provider;
    }
  }
  return null;
}

class ThemePalette {
  const ThemePalette({
    required this.mode,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.surface,
    required this.backgroundTop,
    required this.backgroundBottom,
  });

  final AppThemeMode mode;
  final String name;
  final Color primary;
  final Color secondary;
  final Color surface;
  final Color backgroundTop;
  final Color backgroundBottom;
}

class ModelOption {
  const ModelOption({
    required this.name,
    required this.id,
    required this.blurb,
    this.description,
    this.provider = AiProviderType.openRouter,
    this.customProviderId,
    ModelVisionSupport? visionSupport,
    bool? supportsVision,
    this.supportsStreaming = true,
    this.isFree = true,
    this.isBuiltIn = false,
    this.contextWindow,
    this.maxOutputTokens,
    this.inputPrice,
    this.outputPrice,
  }) : visionSupport = visionSupport ??
            (supportsVision == null
                ? ModelVisionSupport.unknown
                : supportsVision
                    ? ModelVisionSupport.supported
                    : ModelVisionSupport.unsupported);

  final String name;
  final String id;
  final String blurb;
  final String? description;
  final AiProviderType provider;
  final String? customProviderId;
  final ModelVisionSupport visionSupport;
  final bool supportsStreaming;
  final bool isFree;
  final bool isBuiltIn;
  final int? contextWindow;
  final int? maxOutputTokens;
  final String? inputPrice;
  final String? outputPrice;

  bool get supportsVision => visionSupport == ModelVisionSupport.supported;
  bool get hasKnownVisionSupport => visionSupport != ModelVisionSupport.unknown;

  bool sameSelectionIdentity(ModelOption? other) {
    if (other == null) return false;
    if (provider != other.provider || id != other.id) return false;
    final thisCustomProviderId = customProviderId?.trim() ?? '';
    final otherCustomProviderId = other.customProviderId?.trim() ?? '';
    if (thisCustomProviderId != otherCustomProviderId) return false;
    final thisName = _normalizedModelName(name);
    final otherName = _normalizedModelName(other.name);
    if (thisName.isEmpty || otherName.isEmpty) return true;
    return thisName == otherName;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'id': id,
      'blurb': blurb,
      'description': description,
      'provider': provider.name,
      'customProviderId': customProviderId,
      'visionSupport': visionSupport.name,
      'supportsStreaming': supportsStreaming,
      'isFree': isFree,
      'isBuiltIn': isBuiltIn,
      'contextWindow': contextWindow,
      'maxOutputTokens': maxOutputTokens,
      'inputPrice': inputPrice,
      'outputPrice': outputPrice,
    };
  }

  factory ModelOption.fromMap(Map<String, dynamic> map) {
    return ModelOption(
      name: map['name'] as String? ?? 'Custom Model',
      id: map['id'] as String? ?? '',
      blurb: map['blurb'] as String? ?? '',
      description: map['description'] as String?,
      provider: AiProviderType.values.firstWhere(
        (value) => value.name == map['provider'],
        orElse: () => AiProviderType.openRouter,
      ),
      customProviderId: map['customProviderId'] as String?,
      visionSupport: ModelVisionSupport.values.firstWhere(
        (value) => value.name == map['visionSupport'],
        orElse: () => (map['supportsVision'] as bool? ?? false)
            ? ModelVisionSupport.supported
            : ModelVisionSupport.unknown,
      ),
      supportsStreaming: map['supportsStreaming'] as bool? ?? true,
      isFree: map['isFree'] as bool? ?? true,
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
      contextWindow: map['contextWindow'] as int?,
      maxOutputTokens: map['maxOutputTokens'] as int?,
      inputPrice: map['inputPrice'] as String?,
      outputPrice: map['outputPrice'] as String?,
    );
  }
}

String _normalizedModelName(String value) {
  return value.trim().toLowerCase();
}

ModelOption? resolveModelOptionSelection(
  Iterable<ModelOption> options, {
  required String? id,
  String? name,
  AiProviderType? provider,
  String? customProviderId,
}) {
  if (id == null || id.trim().isEmpty) return null;
  final normalizedId = id.trim();
  final normalizedName = name == null ? '' : _normalizedModelName(name);
  final normalizedCustomProviderId = customProviderId?.trim() ?? '';

  ModelOption? findWhere(bool Function(ModelOption option) test) {
    ModelOption? match;
    for (final option in options) {
      if (test(option)) {
        match = option;
      }
    }
    return match;
  }

  final exact = findWhere(
    (option) =>
        option.id == normalizedId &&
        option.provider == provider &&
        (normalizedCustomProviderId.isEmpty ||
            (option.customProviderId?.trim() ?? '') ==
                normalizedCustomProviderId) &&
        (normalizedName.isEmpty ||
            _normalizedModelName(option.name) == normalizedName),
  );
  if (exact != null) return exact;

  final providerAndId = findWhere(
    (option) =>
        option.id == normalizedId &&
        option.provider == provider &&
        (normalizedCustomProviderId.isEmpty ||
            (option.customProviderId?.trim() ?? '') ==
                normalizedCustomProviderId),
  );
  if (providerAndId != null) return providerAndId;

  final idAndName = findWhere(
    (option) =>
        option.id == normalizedId &&
        (normalizedName.isEmpty ||
            _normalizedModelName(option.name) == normalizedName),
  );
  if (idAndName != null) return idAndName;

  return findWhere((option) => option.id == normalizedId);
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.requestText,
    this.attachments = const [],
    this.feedback,
  });

  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final String? requestText;
  final List<ChatAttachment> attachments;
  final MessageFeedback? feedback;

  String get promptText => requestText ?? content;

  bool get hasAttachments => attachments.isNotEmpty;

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? createdAt,
    String? requestText,
    List<ChatAttachment>? attachments,
    MessageFeedback? feedback,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      requestText: requestText ?? this.requestText,
      attachments: attachments ?? this.attachments,
      feedback: feedback ?? this.feedback,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'requestText': requestText,
      'attachments':
          attachments.map((attachment) => attachment.toMap()).toList(),
      'feedback': feedback?.name,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      role: map['role'] as String,
      content: map['content'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      requestText: map['requestText'] as String?,
      attachments: (map['attachments'] as List<dynamic>? ?? const [])
          .map((item) =>
              ChatAttachment.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      feedback: MessageFeedback.values.cast<MessageFeedback?>().firstWhere(
            (value) => value?.name == map['feedback'],
            orElse: () => null,
          ),
    );
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.isStarred = false,
    this.isPinned = false,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  final bool isStarred;
  final bool isPinned;

  String get preview {
    if (messages.isEmpty) return 'Start a new conversation';
    return messages.last.content.replaceAll('\n', ' ').trim();
  }

  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
    bool? isStarred,
    bool? isPinned,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      isStarred: isStarred ?? this.isStarred,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages.map((message) => message.toMap()).toList(),
      'isStarred': isStarred,
      'isPinned': isPinned,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    final rawMessages = map['messages'] as List<dynamic>? ?? const [];
    return ChatSession(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled chat',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      messages: rawMessages
          .map((item) =>
              ChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      isStarred: map['isStarred'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
    );
  }

  static List<ChatSession> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) =>
            ChatSession.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  static String encodeList(List<ChatSession> sessions) {
    return jsonEncode(sessions.map((session) => session.toMap()).toList());
  }
}

int compareChatSessions(ChatSession a, ChatSession b) {
  if (a.isPinned != b.isPinned) {
    return a.isPinned ? -1 : 1;
  }
  return b.updatedAt.compareTo(a.updatedAt);
}

class AppSettings {
  const AppSettings({
    required this.apiKey,
    required this.providerKeys,
    this.customProvider = const CustomProviderConfig(),
    this.customProviders = const <CustomProviderConfig>[],
    required this.selectedModel,
    this.selectedProvider,
    required this.systemPrompt,
    required this.themeMode,
    required this.appearanceMode,
    required this.dynamicThemeEnabled,
    List<ModelOption>? fetchedModels,
    List<ModelOption>? customModels,
    required this.routingMode,
    required this.enabledProviders,
    required this.uiDensityMode,
    required this.appFontPreset,
    required this.chatFontPreset,
    required this.chatColorMode,
  }) : fetchedModels = fetchedModels ?? customModels ?? const [];

  final String apiKey;
  final ProviderKeys providerKeys;
  final CustomProviderConfig customProvider;
  final List<CustomProviderConfig> customProviders;
  final ModelOption? selectedModel;
  final AiProviderType? selectedProvider;
  final String systemPrompt;
  final AppThemeMode themeMode;
  final AppAppearanceMode appearanceMode;
  final bool dynamicThemeEnabled;
  final List<ModelOption> fetchedModels;
  final ChatRoutingMode routingMode;
  final List<AiProviderType> enabledProviders;
  final UiDensityMode uiDensityMode;
  final AppFontPreset appFontPreset;
  final AppFontPreset chatFontPreset;
  final ChatColorMode chatColorMode;
}

enum ComposerAttachmentType {
  image,
  textFile,
  pdf,
  file,
}

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.type,
    this.mediaType,
    this.inlineDataBase64,
    this.extractedText,
  });

  final String name;
  final ComposerAttachmentType type;
  final String? mediaType;
  final String? inlineDataBase64;
  final String? extractedText;

  bool get hasInlineData =>
      inlineDataBase64 != null && inlineDataBase64!.trim().isNotEmpty;

  bool get hasExtractedText =>
      extractedText != null && extractedText!.trim().isNotEmpty;

  int get extractedCharacterCount => extractedText?.trim().length ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name,
      'mediaType': mediaType,
      'inlineDataBase64': inlineDataBase64,
      'extractedText': extractedText,
    };
  }

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    return ChatAttachment(
      name: map['name'] as String? ?? 'Attachment',
      type: ComposerAttachmentType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => ComposerAttachmentType.image,
      ),
      mediaType: map['mediaType'] as String?,
      inlineDataBase64: map['inlineDataBase64'] as String?,
      extractedText: map['extractedText'] as String?,
    );
  }
}

class ComposerAttachment {
  const ComposerAttachment({
    required this.id,
    required this.name,
    required this.type,
    this.mediaType,
    this.previewBytes,
    this.extractedText,
  });

  final String id;
  final String name;
  final ComposerAttachmentType type;
  final String? mediaType;
  final Uint8List? previewBytes;
  final String? extractedText;

  bool get hasPreview => previewBytes != null && previewBytes!.isNotEmpty;

  bool get hasExtractedText =>
      extractedText != null && extractedText!.trim().isNotEmpty;

  int get extractedCharacterCount => extractedText?.trim().length ?? 0;

  String get extractionSummary {
    return 'Image ready';
  }

  ChatAttachment toChatAttachment() {
    return ChatAttachment(
      name: name,
      type: type,
      mediaType: mediaType,
      inlineDataBase64: hasPreview ? base64Encode(previewBytes!) : null,
    );
  }
}

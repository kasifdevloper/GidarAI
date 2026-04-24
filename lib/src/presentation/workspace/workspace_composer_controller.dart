import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/models/app_models.dart';

final workspaceComposerControllerProvider =
    ChangeNotifierProvider.autoDispose<WorkspaceComposerController>(
  (ref) => WorkspaceComposerController(),
);

class ComposerSubmission {
  const ComposerSubmission({
    required this.promptText,
    required this.displayText,
    required this.attachments,
  });

  final String promptText;
  final String displayText;
  final List<ChatAttachment> attachments;
}

class WorkspaceComposerController extends ChangeNotifier {
  WorkspaceComposerController() {
    _promptController.addListener(_handlePromptChanged);
  }

  static const slashCommands = [
    '/new',
    '/clear',
    '/model',
    '/settings',
    '/copy',
    '/export',
    '/help',
  ];

  final TextEditingController _promptController = TextEditingController();
  final List<ComposerAttachment> _attachments = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _showCommandPalette = false;
  bool _showExpandedOptions = false;
  bool _generateImage = false;
  bool _generateDocument = false;
  bool _webSearch = false;
  bool _deepResearch = false;
  String? _editingMessageId;

  TextEditingController get promptController => _promptController;
  List<ComposerAttachment> get attachments => List.unmodifiable(_attachments);
  bool get showCommandPalette => _showCommandPalette;
  bool get showExpandedOptions => _showExpandedOptions;
  bool get generateImage => _generateImage;
  bool get generateDocument => _generateDocument;
  bool get webSearch => _webSearch;
  bool get deepResearch => _deepResearch;
  String? get editingMessageId => _editingMessageId;
  bool get isEditingLastMessage => _editingMessageId != null;
  String get promptText => _promptController.text;
  List<String> get activeModeLabels => [
        if (_generateImage) 'Generate Image',
        if (_generateDocument) 'Generate Document',
        if (_webSearch) 'Web Search',
        if (_deepResearch) 'Deep Research',
      ];

  List<String> get filteredCommands {
    final query = _promptController.text.trim();
    if (!query.startsWith('/')) return const [];
    return slashCommands.where((command) => command.startsWith(query)).toList();
  }

  void toggleExpandedOptions() {
    _showExpandedOptions = !_showExpandedOptions;
    notifyListeners();
  }

  void collapseExpandedOptions() {
    if (!_showExpandedOptions) return;
    _showExpandedOptions = false;
    notifyListeners();
  }

  void toggleGenerateImage() {
    _generateImage = !_generateImage;
    notifyListeners();
  }

  void toggleGenerateDocument() {
    _generateDocument = !_generateDocument;
    notifyListeners();
  }

  void toggleWebSearch() {
    _webSearch = !_webSearch;
    notifyListeners();
  }

  void toggleDeepResearch() {
    _deepResearch = !_deepResearch;
    notifyListeners();
  }

  void removeAttachment(String id) {
    final beforeCount = _attachments.length;
    _attachments.removeWhere((item) => item.id == id);
    if (_attachments.length != beforeCount) {
      notifyListeners();
    }
  }

  void setPromptText(String text) {
    _promptController.text = text;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  void beginEditingMessage({
    required String messageId,
    required String text,
    List<ComposerAttachment> attachments = const [],
  }) {
    final hadDifferentMessage = _editingMessageId != messageId;
    final attachmentsChanged = !_composerAttachmentsEqual(
      _attachments,
      attachments,
    );
    _editingMessageId = messageId;
    setPromptText(text);
    _attachments
      ..clear()
      ..addAll(attachments);
    if (hadDifferentMessage || attachmentsChanged) {
      notifyListeners();
    }
  }

  void cancelEditingMessage() {
    if (_editingMessageId == null) return;
    _editingMessageId = null;
    notifyListeners();
  }

  void clearForSlashCommand() {
    _promptController.clear();
    final wasEditing = _editingMessageId != null;
    _editingMessageId = null;
    if (_showCommandPalette) {
      _showCommandPalette = false;
      notifyListeners();
      return;
    }
    if (wasEditing) {
      notifyListeners();
    }
  }

  void clearAfterSubmit() {
    final hadAttachments = _attachments.isNotEmpty;
    final hadExpandedOptions = _showExpandedOptions;
    final wasEditing = _editingMessageId != null;
    _promptController.clear();
    _attachments.clear();
    _showExpandedOptions = false;
    _editingMessageId = null;
    if (hadAttachments || hadExpandedOptions || wasEditing) {
      notifyListeners();
    }
  }

  ComposerSubmission buildSubmission(String prompt) {
    final promptWithModes = _composePromptWithModes(prompt);
    if (_attachments.isEmpty) {
      return ComposerSubmission(
        promptText: promptWithModes,
        displayText: _composeDisplayText(prompt),
        attachments: const [],
      );
    }

    final buffer = StringBuffer(_composeDisplayText(prompt));
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('Attachments:');
    for (final attachment in _attachments) {
      buffer.writeln('- ${attachment.name}');
    }
    return ComposerSubmission(
      promptText: promptWithModes,
      displayText: buffer.toString().trim(),
      attachments: _attachments.map((item) => item.toChatAttachment()).toList(),
    );
  }

  Future<String?> pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final availableSlots = 5 - _attachments.length;
    if (availableSlots <= 0) {
      return 'Maximum 5 attachments allowed.';
    }

    final incoming = result.files.take(availableSlots).map((file) {
      return ComposerAttachment(
        id: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
        name: file.name,
        type: ComposerAttachmentType.image,
        mediaType: _mimeTypeForExtension(file.extension),
        previewBytes: file.bytes,
      );
    }).toList();
    _attachments.addAll(incoming);
    notifyListeners();
    return _formatImportSummary(
      importedCount: incoming.length,
      noun: incoming.length == 1 ? 'image' : 'images',
      truncated: result.files.length > availableSlots,
    );
  }

  Future<String?> captureCameraImage() async {
    final availableSlots = 5 - _attachments.length;
    if (availableSlots <= 0) {
      return 'Maximum 5 attachments allowed.';
    }

    final captured = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (captured == null) return null;

    final bytes = await captured.readAsBytes();
    _attachments.add(
      ComposerAttachment(
        id: '${DateTime.now().microsecondsSinceEpoch}-${captured.name}',
        name: captured.name.isEmpty ? 'camera_capture.jpg' : captured.name,
        type: ComposerAttachmentType.image,
        mediaType: _mimeTypeForExtension(
          captured.name.contains('.') ? captured.name.split('.').last : 'jpg',
        ),
        previewBytes: bytes,
      ),
    );
    notifyListeners();
    return '1 camera image added';
  }

  void addAttachmentForTest(ComposerAttachment attachment) {
    _attachments.add(attachment);
    notifyListeners();
  }

  Future<List<ComposerAttachment>> attachmentsFromFilesForTest(
    List<PlatformFile> files,
  ) async {
    return files.map((file) {
      return ComposerAttachment(
        id: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
        name: file.name,
        type: ComposerAttachmentType.image,
        mediaType: _mimeTypeForExtension(file.extension),
        previewBytes: file.bytes,
      );
    }).toList();
  }

  List<ComposerAttachment> attachmentsFromChatAttachments(
    List<ChatAttachment> attachments,
  ) {
    return attachments
        .where((attachment) => attachment.type == ComposerAttachmentType.image)
        .map((attachment) {
      Uint8List? previewBytes;
      if (attachment.hasInlineData) {
        try {
          previewBytes = base64Decode(attachment.inlineDataBase64!);
        } on FormatException {
          previewBytes = null;
        }
      }

      return ComposerAttachment(
        id: '${DateTime.now().microsecondsSinceEpoch}-${attachment.name}',
        name: attachment.name,
        type: ComposerAttachmentType.image,
        mediaType: attachment.mediaType,
        previewBytes: previewBytes,
      );
    }).toList();
  }

  String _formatImportSummary({
    required int importedCount,
    required String noun,
    List<String> details = const [],
    bool truncated = false,
  }) {
    final buffer = StringBuffer();
    buffer.write('$importedCount $noun added');
    if (details.isNotEmpty) {
      buffer.write(' • ${details.join(' • ')}');
    }
    if (truncated) {
      buffer.write(' • Maximum 5 attachments allowed.');
    }
    return buffer.toString();
  }

  String _composeDisplayText(String prompt) {
    final modes = activeModeLabels;
    if (modes.isEmpty) return prompt;
    return '$prompt\n\nModes: ${modes.join(' • ')}';
  }

  String _composePromptWithModes(String prompt) {
    final instructions = <String>[
      if (_generateImage)
        'The user wants an image-oriented response or image creation help.',
      if (_generateDocument)
        'Prefer a polished document-style output with clear structure.',
      if (_webSearch)
        'Prefer a web-assisted, source-aware answer when possible.',
      if (_deepResearch)
        'Answer in deep-research mode with careful reasoning, coverage, and tradeoffs.',
    ];
    if (instructions.isEmpty) {
      return prompt;
    }
    return '''
$prompt

Mode preferences:
- ${instructions.join('\n- ')}
'''
        .trim();
  }

  String? _mimeTypeForExtension(String? extension) {
    return switch (extension?.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => null,
    };
  }

  void _handlePromptChanged() {
    final shouldShow = _promptController.text.trimLeft().startsWith('/');
    if (shouldShow == _showCommandPalette) return;
    _showCommandPalette = shouldShow;
    notifyListeners();
  }

  @override
  void dispose() {
    _promptController.removeListener(_handlePromptChanged);
    _promptController.dispose();
    super.dispose();
  }

  bool _composerAttachmentsEqual(
    List<ComposerAttachment> left,
    List<ComposerAttachment> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      final leftItem = left[index];
      final rightItem = right[index];
      if (leftItem.name != rightItem.name ||
          leftItem.type != rightItem.type ||
          leftItem.mediaType != rightItem.mediaType) {
        return false;
      }
      final leftBytes = leftItem.previewBytes;
      final rightBytes = rightItem.previewBytes;
      if (leftBytes == null || rightBytes == null) {
        if (leftBytes != rightBytes) {
          return false;
        }
        continue;
      }
      if (leftBytes.length != rightBytes.length) {
        return false;
      }
      for (var byteIndex = 0; byteIndex < leftBytes.length; byteIndex += 1) {
        if (leftBytes[byteIndex] != rightBytes[byteIndex]) {
          return false;
        }
      }
    }
    return true;
  }
}

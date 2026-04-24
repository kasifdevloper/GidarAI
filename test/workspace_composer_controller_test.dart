import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/presentation/workspace/workspace_composer_controller.dart';

void main() {
  test('slash command palette follows prompt prefix', () {
    final controller = WorkspaceComposerController();
    addTearDown(controller.dispose);

    controller.setPromptText('/mo');
    expect(controller.showCommandPalette, isTrue);
    expect(controller.filteredCommands, contains('/model'));

    controller.setPromptText('hello');
    expect(controller.showCommandPalette, isFalse);
    expect(controller.filteredCommands, isEmpty);
  });

  test('buildSubmission keeps request text separate from display text', () {
    final controller = WorkspaceComposerController();
    addTearDown(controller.dispose);

    controller.setPromptText('Summarize this');
    controller.addAttachmentForTest(
      const ComposerAttachment(
        id: '1',
        name: 'first.png',
        type: ComposerAttachmentType.image,
        mediaType: 'image/png',
      ),
    );
    controller.addAttachmentForTest(
      const ComposerAttachment(
        id: '2',
        name: 'diagram.png',
        type: ComposerAttachmentType.image,
        mediaType: 'image/png',
      ),
    );

    final submission = controller.buildSubmission('Summarize this');
    expect(submission.promptText, 'Summarize this');
    expect(submission.displayText, contains('Attachments:'));
    expect(submission.displayText, contains('first.png'));
    expect(submission.displayText, contains('diagram.png'));
    expect(submission.attachments, hasLength(2));
    expect(submission.attachments.first.type, ComposerAttachmentType.image);
    expect(submission.attachments.last.mediaType, 'image/png');

    controller.toggleExpandedOptions();
    controller.clearAfterSubmit();
    expect(controller.promptText, isEmpty);
    expect(controller.attachments, isEmpty);
    expect(controller.showExpandedOptions, isFalse);
  });

  test('attachmentsFromFilesForTest keeps image attachments ready for preview',
      () async {
    final controller = WorkspaceComposerController();
    addTearDown(controller.dispose);

    final attachments = await controller.attachmentsFromFilesForTest([
      PlatformFile(
        name: 'one.png',
        size: 12,
        bytes: Uint8List.fromList(const [1, 2, 3]),
      ),
      PlatformFile(
        name: 'two.jpg',
        size: 64,
        bytes: Uint8List.fromList(const [4, 5, 6]),
      ),
    ]);

    expect(attachments, hasLength(2));
    expect(attachments.first.type, ComposerAttachmentType.image);
    expect(attachments.first.mediaType, 'image/png');
    expect(attachments.last.type, ComposerAttachmentType.image);
    expect(attachments.last.mediaType, 'image/jpeg');
  });

  test('buildSubmission includes active mode hints when toggles are enabled',
      () {
    final controller = WorkspaceComposerController();
    addTearDown(controller.dispose);

    controller.toggleGenerateDocument();
    controller.toggleWebSearch();

    final submission = controller.buildSubmission('Create a report');

    expect(submission.promptText, contains('Mode preferences:'));
    expect(submission.promptText, contains('polished document-style output'));
    expect(
        submission.promptText, contains('web-assisted, source-aware answer'));
    expect(submission.displayText,
        contains('Modes: Generate Document • Web Search'));
    expect(controller.activeModeLabels, ['Generate Document', 'Web Search']);
  });

  test('editing state is tracked and cleared after submit', () {
    final controller = WorkspaceComposerController();
    addTearDown(controller.dispose);

    controller.beginEditingMessage(
      messageId: 'user-2',
      text: 'Apple kya hai?',
    );

    expect(controller.isEditingLastMessage, isTrue);
    expect(controller.editingMessageId, 'user-2');
    expect(controller.promptText, 'Apple kya hai?');

    controller.clearAfterSubmit();

    expect(controller.isEditingLastMessage, isFalse);
    expect(controller.editingMessageId, isNull);
    expect(controller.promptText, isEmpty);
  });

  test('beginEditingMessage restores image attachments for edit flow', () {
    final controller = WorkspaceComposerController();
    addTearDown(controller.dispose);

    final attachments = controller.attachmentsFromChatAttachments(
      const [
        ChatAttachment(
          name: 'diagram.png',
          type: ComposerAttachmentType.image,
          mediaType: 'image/png',
          inlineDataBase64: 'AQID',
        ),
      ],
    );

    controller.beginEditingMessage(
      messageId: 'user-3',
      text: 'Explain this image',
      attachments: attachments,
    );

    expect(controller.isEditingLastMessage, isTrue);
    expect(controller.attachments, hasLength(1));
    expect(controller.attachments.single.name, 'diagram.png');
    expect(controller.attachments.single.previewBytes,
        Uint8List.fromList(const [1, 2, 3]));
  });
}

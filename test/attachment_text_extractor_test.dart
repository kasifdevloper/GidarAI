import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/services/attachment_text_extractor.dart';

void main() {
  test('extractText returns normalized text for text files', () {
    final bytes = Uint8List.fromList(utf8.encode('Line one\r\n\r\n\r\nLine two'));

    final extracted = AttachmentTextExtractor.extractText(bytes);

    expect(extracted, 'Line one\n\nLine two');
  });

  test('extractText ignores binary-looking files', () {
    final bytes = Uint8List.fromList([0, 159, 146, 150, 1, 2, 3, 4]);

    final extracted = AttachmentTextExtractor.extractText(bytes);

    expect(extracted, isNull);
  });

  test('extractPdfText decodes literal strings inside text blocks', () {
    final bytes = Uint8List.fromList(
      latin1.encode(
        '%PDF-1.4\n'
        '1 0 obj\n'
        '<< /Length 44 >>\n'
        'stream\n'
        'BT\n'
        '/F1 12 Tf\n'
        '72 720 Td\n'
        '(Hello\\040PDF) Tj\n'
        '0 -16 Td\n'
        '(Second line) Tj\n'
        'ET\n'
        'endstream\n'
        'endobj\n',
      ),
    );

    final extracted = AttachmentTextExtractor.extractPdfText(bytes);

    expect(extracted, 'Hello PDF\nSecond line');
  });

  test('extractPdfText decodes hex encoded utf16 strings', () {
    final bytes = Uint8List.fromList(
      latin1.encode(
        '%PDF-1.4\n'
        'BT\n'
        '<FEFF00480065006C006C006F0020005000440046> Tj\n'
        'ET\n',
      ),
    );

    final extracted = AttachmentTextExtractor.extractPdfText(bytes);

    expect(extracted, 'Hello PDF');
  });

  test('extract truncates very large content', () {
    final text = 'A' * (AttachmentTextExtractor.maxExtractedCharacters + 200);
    final bytes = Uint8List.fromList(utf8.encode(text));

    final extracted = AttachmentTextExtractor.extractText(bytes);

    expect(extracted, endsWith('[Attachment text truncated]'));
  });
}

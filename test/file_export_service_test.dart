import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/services/file_export_service.dart';

void main() {
  test('ensureExportFileName keeps svg and dart extensions stable', () {
    expect(
      ensureExportFileName('image', language: 'svg'),
      'image.svg',
    );
    expect(
      ensureExportFileName('main.txt', language: 'dart'),
      'main.dart',
    );
  });

  test('inferMimeType resolves dart and svg exports correctly', () {
    expect(
      inferMimeType('main.dart', language: 'dart'),
      'text/x-dart',
    );
    expect(
      inferMimeType('image.svg', language: 'svg'),
      'image/svg+xml',
    );
  });

  test('inferShareMimeType keeps svg and dart as generic file shares', () {
    expect(
      inferShareMimeType('image.svg', language: 'svg'),
      isNull,
    );
    expect(
      inferShareMimeType('main.dart', language: 'dart'),
      isNull,
    );
  });
}

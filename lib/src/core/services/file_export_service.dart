import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const MethodChannel _downloadsChannel = MethodChannel('ai.gidar.app/downloads');

String ensureExportFileName(
  String fileName, {
  String? language,
}) {
  final extension = p.extension(fileName).toLowerCase();
  final expectedExtension = switch (language?.toLowerCase()) {
    'html' => '.html',
    'svg' => '.svg',
    'dart' => '.dart',
    'css' => '.css',
    'javascript' || 'js' => '.js',
    'typescript' || 'ts' => '.ts',
    _ => extension,
  };

  if (extension.isEmpty && expectedExtension.isNotEmpty) {
    return '$fileName$expectedExtension';
  }

  if (expectedExtension.isNotEmpty &&
      extension.isNotEmpty &&
      extension != expectedExtension) {
    return '${p.withoutExtension(fileName)}$expectedExtension';
  }

  return fileName;
}

String inferMimeType(
  String fileName, {
  String? language,
}) {
  final normalizedFileName = ensureExportFileName(
    fileName,
    language: language,
  );
  final extension = p.extension(normalizedFileName).toLowerCase();
  final normalizedLanguage = language?.toLowerCase();
  return switch (
      extension.isNotEmpty ? extension : '.${normalizedLanguage ?? 'txt'}') {
    '.html' || '.htm' => 'text/html',
    '.svg' => 'image/svg+xml',
    '.css' => 'text/css',
    '.js' => 'application/javascript',
    '.ts' => 'text/plain',
    '.json' => 'application/json',
    '.xml' => 'application/xml',
    '.sql' => 'text/plain',
    '.md' => 'text/markdown',
    '.txt' => 'text/plain',
    '.dart' => 'text/x-dart',
    _ => 'text/plain',
  };
}

String? inferShareMimeType(
  String fileName, {
  String? language,
}) {
  final normalizedFileName = ensureExportFileName(
    fileName,
    language: language,
  );
  final extension = p.extension(normalizedFileName).toLowerCase();
  return switch (extension) {
    '.svg' || '.dart' => null,
    _ => inferMimeType(normalizedFileName, language: language),
  };
}

Future<File> createSharedTextFile({
  required String fileName,
  required String content,
}) async {
  final normalizedFileName = ensureExportFileName(fileName);
  final directory = await getTemporaryDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File(p.join(directory.path, '${timestamp}_$normalizedFileName'));
  await file.writeAsString(content, flush: true);
  return file;
}

Future<void> shareTextFile({
  required String fileName,
  required String content,
  String? mimeType,
  String? language,
}) async {
  final normalizedFileName = ensureExportFileName(
    fileName,
    language: language,
  );
  final file = await createSharedTextFile(
    fileName: normalizedFileName,
    content: content,
  );
  await Share.shareXFiles(
    [
      XFile(
        file.path,
        mimeType: mimeType ?? inferShareMimeType(normalizedFileName),
        name: normalizedFileName,
      ),
    ],
    subject: normalizedFileName,
  );
}

Future<String> saveTextFileToDownloads({
  required String fileName,
  required String content,
  String? mimeType,
  String? language,
}) async {
  final normalizedFileName = ensureExportFileName(
    fileName,
    language: language,
  );
  final resolvedMimeType =
      mimeType ?? inferMimeType(normalizedFileName, language: language);
  if (Platform.isAndroid) {
    try {
      final path = await _downloadsChannel.invokeMethod<String>(
        'saveTextFile',
        <String, Object?>{
          'fileName': normalizedFileName,
          'content': content,
          'mimeType': resolvedMimeType,
        },
      );
      if (path != null && path.isNotEmpty) {
        return path;
      }
    } on PlatformException {
      // Fall back to a local file path when platform save is unavailable.
    }
  }

  final fallbackDirectory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final file = File(p.join(fallbackDirectory.path, normalizedFileName));
  await file.writeAsString(content, flush: true);
  return file.path;
}

Future<String> saveBinaryFileToDownloads({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  if (Platform.isAndroid) {
    try {
      final path = await _downloadsChannel.invokeMethod<String>(
        'saveBinaryFile',
        <String, Object?>{
          'fileName': fileName,
          'bytes': bytes,
          'mimeType': mimeType,
        },
      );
      if (path != null && path.isNotEmpty) {
        return path;
      }
    } on PlatformException {
      // Fall back to a local file path when platform save is unavailable.
    }
  }

  final fallbackDirectory =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final exportDirectory = Directory(p.join(fallbackDirectory.path, 'GidarAI'));
  if (!await exportDirectory.exists()) {
    await exportDirectory.create(recursive: true);
  }
  final file = File(p.join(exportDirectory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

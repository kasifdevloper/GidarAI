import 'dart:convert';
import 'dart:typed_data';

class AttachmentTextExtractor {
  const AttachmentTextExtractor._();

  static const int maxExtractedCharacters = 12000;

  static String? extract({
    required Uint8List? bytes,
    String? extension,
  }) {
    if (bytes == null || bytes.isEmpty) return null;
    final normalizedExtension = extension?.toLowerCase().trim();
    if (normalizedExtension == 'pdf') {
      return extractPdfText(bytes);
    }
    return extractText(bytes);
  }

  static String? extractText(Uint8List bytes) {
    if (bytes.isEmpty || _looksBinary(bytes)) return null;
    final decoded = utf8.decode(bytes, allowMalformed: true);
    return _normalize(decoded);
  }

  static String? extractPdfText(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final source = latin1.decode(bytes, allowInvalid: true);
    final extracted = <String>[];

    final textBlocks = RegExp(r'BT[\s\S]*?ET').allMatches(source);
    for (final block in textBlocks) {
      final text = block.group(0);
      if (text == null) continue;
      extracted.addAll(_extractPdfLiteralStrings(text));
      extracted.addAll(_extractPdfHexStrings(text));
    }

    if (extracted.isEmpty) {
      extracted.addAll(_extractPdfLiteralStrings(source));
      extracted.addAll(_extractPdfHexStrings(source));
    }

    return _normalize(extracted.join('\n'));
  }

  static Iterable<String> _extractPdfLiteralStrings(String input) sync* {
    for (final match in RegExp(r'\((?:\\.|[^\\()])*\)').allMatches(input)) {
      final raw = match.group(0);
      if (raw == null || raw.length < 2) continue;
      final decoded = _decodePdfLiteralString(raw.substring(1, raw.length - 1));
      if (_looksUsefulPdfText(decoded)) {
        yield decoded;
      }
    }
  }

  static Iterable<String> _extractPdfHexStrings(String input) sync* {
    for (final match in RegExp(r'<([0-9A-Fa-f\s]+)>').allMatches(input)) {
      final raw = match.group(1);
      if (raw == null) continue;
      final normalized = raw.replaceAll(RegExp(r'\s+'), '');
      if (normalized.length < 4 || normalized.length.isOdd) continue;
      final decoded = _decodePdfHexString(normalized);
      if (_looksUsefulPdfText(decoded)) {
        yield decoded;
      }
    }
  }

  static String _decodePdfLiteralString(String value) {
    final buffer = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char != r'\') {
        buffer.write(char);
        continue;
      }

      if (index + 1 >= value.length) break;
      final next = value[++index];
      if (next == 'n') {
        buffer.write('\n');
      } else if (next == 'r') {
        buffer.write('\r');
      } else if (next == 't') {
        buffer.write('\t');
      } else if (next == 'b') {
        buffer.write('\b');
      } else if (next == 'f') {
        buffer.write('\f');
      } else if (next == '(' || next == ')' || next == r'\') {
        buffer.write(next);
      } else if (next == '\n') {
        // PDF line continuation escape.
      } else if (next == '\r') {
        if (index + 1 < value.length && value[index + 1] == '\n') {
          index++;
        }
      } else if (_isOctalDigit(next)) {
        final octal = StringBuffer(next);
        for (var lookAhead = 0; lookAhead < 2; lookAhead++) {
          if (index + 1 >= value.length || !_isOctalDigit(value[index + 1])) {
            break;
          }
          octal.write(value[++index]);
        }
        buffer.writeCharCode(int.parse(octal.toString(), radix: 8));
      } else {
        buffer.write(next);
      }
    }
    return buffer.toString();
  }

  static String _decodePdfHexString(String value) {
    final bytes = <int>[];
    for (var index = 0; index < value.length; index += 2) {
      bytes.add(int.parse(value.substring(index, index + 2), radix: 16));
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16Be(bytes.skip(2).toList());
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16Le(bytes.skip(2).toList());
    }

    final ascii = bytes
        .where((byte) => byte == 9 || byte == 10 || byte == 13 || byte >= 32)
        .toList();
    if (ascii.length == bytes.length) {
      return latin1.decode(bytes, allowInvalid: true);
    }

    if (bytes.length.isEven) {
      final utf16Candidate = _decodeUtf16Be(bytes);
      if (_looksUsefulPdfText(utf16Candidate)) {
        return utf16Candidate;
      }
    }

    return latin1.decode(bytes, allowInvalid: true);
  }

  static String _decodeUtf16Be(List<int> bytes) {
    final codeUnits = <int>[];
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      codeUnits.add((bytes[index] << 8) | bytes[index + 1]);
    }
    return String.fromCharCodes(codeUnits);
  }

  static String _decodeUtf16Le(List<int> bytes) {
    final codeUnits = <int>[];
    for (var index = 0; index + 1 < bytes.length; index += 2) {
      codeUnits.add((bytes[index + 1] << 8) | bytes[index]);
    }
    return String.fromCharCodes(codeUnits);
  }

  static bool _isOctalDigit(String value) => RegExp(r'[0-7]').hasMatch(value);

  static bool _looksUsefulPdfText(String value) {
    final normalized = value.trim();
    if (normalized.length < 2) return false;
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(normalized)) return false;
    return normalized.runes.any((codePoint) => codePoint >= 32 && codePoint != 127);
  }

  static bool _looksBinary(Uint8List bytes) {
    var suspiciousCount = 0;
    final sampleLength = bytes.length > 512 ? 512 : bytes.length;
    for (var index = 0; index < sampleLength; index++) {
      final unit = bytes[index];
      final isAllowedControl = unit == 9 || unit == 10 || unit == 13;
      if (unit == 0) return true;
      if (unit < 32 && !isAllowedControl) {
        suspiciousCount++;
      }
    }
    return suspiciousCount > sampleLength * 0.1;
  }

  static String? _normalize(String value) {
    final cleaned = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.length <= maxExtractedCharacters) {
      return cleaned;
    }
    final truncated = cleaned.substring(0, maxExtractedCharacters).trimRight();
    return '$truncated\n\n[Attachment text truncated]';
  }
}

import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart';

import '../../core/theme/app_theme.dart';

class DetectedFile {
  const DetectedFile({
    required this.fileName,
    required this.language,
    required this.code,
    required this.isLarge,
  });

  final String fileName;
  final String language;
  final String code;
  final bool isLarge;
}

class ParsedCodeBlock {
  const ParsedCodeBlock({
    required this.language,
    required this.code,
  });

  final String language;
  final String code;
}

ParsedCodeBlock parseCodeBlock(String codeBlock) {
  final cleaned = codeBlock.replaceAll('```', '');
  final lines = cleaned.split('\n');
  final language = lines.isNotEmpty && lines.first.trim().isNotEmpty
      ? lines.first.trim()
      : 'code';
  final code = lines.skip(1).join('\n').trim();
  return ParsedCodeBlock(language: language, code: code);
}

ParsedCodeBlock? extractFirstCodeBlock(String input) {
  final regex = RegExp(r'```[\s\S]*?```');
  final match = regex.firstMatch(input);
  if (match == null) return null;
  return parseCodeBlock(match.group(0)!);
}

String? extractHtmlCode(String input) {
  final block = extractFirstCodeBlock(input);
  if (block == null) return null;
  final looksHtml = block.language.toLowerCase() == 'html' ||
      block.code.trimLeft().startsWith('<');
  return looksHtml ? block.code : null;
}

bool looksLikeSvgCode(String code, String language) {
  final lang = language.toLowerCase();
  final trimmed = code.trimLeft().toLowerCase();
  return lang == 'svg' || trimmed.startsWith('<svg');
}

bool looksLikeHtmlCode(String code, String language) {
  final lang = language.toLowerCase();
  final trimmed = code.trimLeft().toLowerCase();
  if (lang == 'html' || lang == 'htm') {
    return true;
  }
  if (trimmed.startsWith('<!doctype html') ||
      trimmed.startsWith('<html') ||
      trimmed.startsWith('<head') ||
      trimmed.startsWith('<body') ||
      trimmed.startsWith('<main') ||
      trimmed.startsWith('<section') ||
      trimmed.startsWith('<article') ||
      trimmed.startsWith('<div')) {
    return true;
  }
  return trimmed.contains('</html>') ||
      trimmed.contains('</body>') ||
      trimmed.contains('<style') ||
      trimmed.contains('<script');
}

List<String> splitMarkdown(String input) {
  final regex = RegExp(r'```[\s\S]*?```');
  final matches = regex.allMatches(input);
  if (matches.isEmpty) return [input];

  final parts = <String>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      parts.add(input.substring(cursor, match.start));
    }
    parts.add(input.substring(match.start, match.end));
    cursor = match.end;
  }
  if (cursor < input.length) {
    parts.add(input.substring(cursor));
  }
  return parts;
}

String normalizeStreamingMarkdown(String input) {
  final fenceCount = RegExp(r'```').allMatches(input).length;
  if (fenceCount.isOdd) {
    return '$input\n```';
  }
  return input;
}

bool looksLikeRichMarkdown(String input) {
  final trimmed = input.trimLeft();
  if (trimmed.startsWith('```')) return true;
  if (trimmed.startsWith('#')) return true;
  if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) return true;
  if (trimmed.startsWith('>')) return true;
  if (trimmed.contains('| ---') || trimmed.contains('\n|')) return true;
  if (trimmed.contains('**') ||
      trimmed.contains('_') ||
      trimmed.contains('`')) {
    return true;
  }
  if (trimmed.contains('<html') ||
      trimmed.contains('<div') ||
      trimmed.contains('<body')) {
    return true;
  }
  return false;
}

bool isStreamingHtmlCode(String input) {
  final trimmed = input.trimLeft().toLowerCase();
  if (trimmed.startsWith('```html')) return true;
  if (trimmed.startsWith('<!doctype html') ||
      trimmed.startsWith('<html') ||
      trimmed.startsWith('<body') ||
      trimmed.startsWith('<div')) {
    return true;
  }
  return input.contains('```html');
}

// --- File Detection ---

DetectedFile? detectFileFromCodeBlock(String code, String language) {
  final lineCount = '\n'.allMatches(code).length + 1;
  final lang = language.toLowerCase();

  final isHtml = looksLikeHtmlCode(code, lang);
  final isFullHtml = code.trimLeft().toLowerCase().startsWith('<!doctype html') ||
      code.trimLeft().toLowerCase().startsWith('<html');

  if (isHtml && lineCount >= 3) {
    return DetectedFile(
      fileName: 'index.html',
      language: 'html',
      code: code,
      isLarge: isFullHtml || lineCount >= 12,
    );
  }

  if (looksLikeSvgCode(code, lang)) {
    return DetectedFile(
      fileName: 'image.svg',
      language: 'svg',
      code: code,
      isLarge: lineCount >= 8,
    );
  }

  if (lang == 'dart' && lineCount >= 6) {
    return DetectedFile(
      fileName: 'main.dart',
      language: 'dart',
      code: code,
      isLarge: lineCount >= 12,
    );
  }

  // Large code blocks (40+ lines)
  if (lineCount >= 40) {
    final fileName = defaultFileName(lang);
    return DetectedFile(
      fileName: fileName,
      language: lang,
      code: code,
      isLarge: true,
    );
  }

  // CSS with significant content
  if (lang == 'css' && lineCount >= 15) {
    return DetectedFile(
      fileName: 'style.css',
      language: 'css',
      code: code,
      isLarge: true,
    );
  }

  // JS with significant content
  if ((lang == 'javascript' || lang == 'js') && lineCount >= 20) {
    return DetectedFile(
      fileName: 'script.js',
      language: 'javascript',
      code: code,
      isLarge: true,
    );
  }

  return null;
}

String defaultFileName(String language) {
  return switch (language) {
    'html' => 'index.html',
    'css' => 'style.css',
    'javascript' || 'js' => 'script.js',
    'typescript' || 'ts' => 'script.ts',
    'dart' => 'main.dart',
    'python' || 'py' => 'main.py',
    'java' => 'Main.java',
    'kotlin' || 'kt' => 'Main.kt',
    'swift' => 'main.swift',
    'rust' || 'rs' => 'main.rs',
    'go' => 'main.go',
    'c' => 'main.c',
    'cpp' || 'c++' => 'main.cpp',
    'ruby' || 'rb' => 'main.rb',
    'php' => 'index.php',
    'json' => 'data.json',
    'yaml' || 'yml' => 'config.yaml',
    'sql' => 'query.sql',
    'svg' => 'image.svg',
    'sh' || 'bash' || 'shell' => 'script.sh',
    'xml' => 'data.xml',
    _ => 'file.$language',
  };
}

String fileExtension(String language) {
  return switch (language.toLowerCase()) {
    'html' => '.html',
    'css' => '.css',
    'javascript' || 'js' => '.js',
    'typescript' || 'ts' => '.ts',
    'dart' => '.dart',
    'python' || 'py' => '.py',
    'java' => '.java',
    'kotlin' || 'kt' => '.kt',
    'swift' => '.swift',
    'rust' || 'rs' => '.rs',
    'go' => '.go',
    'c' => '.c',
    'cpp' || 'c++' => '.cpp',
    'ruby' || 'rb' => '.rb',
    'php' => '.php',
    'json' => '.json',
    'yaml' || 'yml' => '.yaml',
    'sql' => '.sql',
    'svg' => '.svg',
    'sh' || 'bash' || 'shell' => '.sh',
    'xml' => '.xml',
    _ => '.txt',
  };
}

IconData fileIcon(String language) {
  return switch (language.toLowerCase()) {
    'html' => Icons.html_rounded,
    'css' => Icons.css_rounded,
    'javascript' || 'js' => Icons.javascript_rounded,
    'typescript' || 'ts' => Icons.code_rounded,
    'dart' => Icons.flutter_dash_rounded,
    'python' || 'py' => Icons.code_rounded,
    'java' => Icons.code_rounded,
    'json' => Icons.data_object_rounded,
    'sql' => Icons.storage_rounded,
    'svg' => Icons.image_outlined,
    'xml' => Icons.code_rounded,
    _ => Icons.description_rounded,
  };
}

Color fileIconColor(String language) {
  return switch (language.toLowerCase()) {
    'html' => const Color(0xFFE44D26),
    'css' => const Color(0xFF264DE4),
    'javascript' || 'js' => const Color(0xFFF7DF1E),
    'typescript' || 'ts' => const Color(0xFF3178C6),
    'dart' => const Color(0xFF00D2B8),
    'python' || 'py' => const Color(0xFF3776AB),
    'json' => const Color(0xFFFFA500),
    'sql' => const Color(0xFF336791),
    'svg' => const Color(0xFFFF6B6B),
    _ => const Color(0xFF6AA2FF),
  };
}

// --- Syntax Highlighting ---

Map<String, TextStyle> buildCodeHighlightTheme({
  required AppThemeTokens tokens,
  required Brightness brightness,
}) {
  final isDark = brightness == Brightness.dark;
  final rootColor = tokens.foreground.withValues(alpha: isDark ? 0.94 : 0.96);
  final commentColor = Color.lerp(
    isDark ? const Color(0xFF74C06B) : const Color(0xFF64748B),
    tokens.mutedForeground,
    isDark ? 0.24 : 0.7,
  )!;
  final keywordColor = Color.lerp(
    isDark ? const Color(0xFFD896FF) : const Color(0xFF7C3AED),
    tokens.accent,
    isDark ? 0.3 : 0.4,
  )!;
  final typeColor = Color.lerp(
    isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
    tokens.accent,
    isDark ? 0.18 : 0.22,
  )!;
  final tagColor = Color.lerp(
    isDark ? const Color(0xFF6AB7FF) : const Color(0xFF2563EB),
    tokens.accent,
    isDark ? 0.18 : 0.28,
  )!;

  return {
    'root': TextStyle(color: rootColor),
    'keyword': TextStyle(color: keywordColor),
    'keyworddeclaration': TextStyle(color: keywordColor),
    'keywordflow': TextStyle(color: keywordColor),
    'built_in': TextStyle(color: typeColor),
    'type': TextStyle(color: typeColor),
    'literal': TextStyle(color: tagColor),
    'number': TextStyle(
      color: isDark ? const Color(0xFFC4F1A3) : const Color(0xFF2E8B57),
    ),
    'string': TextStyle(
      color: isDark ? const Color(0xFFFFC089) : const Color(0xFFC2410C),
    ),
    'string_': TextStyle(
      color: isDark ? const Color(0xFFFFC089) : const Color(0xFFC2410C),
    ),
    'subst': TextStyle(color: rootColor),
    'comment': TextStyle(
      color: commentColor,
      fontStyle: FontStyle.italic,
    ),
    'doctag': TextStyle(color: commentColor),
    'tag': TextStyle(color: tagColor),
    'name': TextStyle(
      color: isDark ? const Color(0xFF83E1FF) : const Color(0xFF0369A1),
    ),
    'attr': TextStyle(
      color: isDark ? const Color(0xFFA9E2FF) : const Color(0xFF075985),
    ),
    'attribute': TextStyle(
      color: isDark ? const Color(0xFFA9E2FF) : const Color(0xFF075985),
    ),
    'selector': TextStyle(
      color: isDark ? const Color(0xFFFFE08A) : const Color(0xFFB45309),
    ),
    'selectorattr': TextStyle(
      color: isDark ? const Color(0xFFFFE08A) : const Color(0xFFB45309),
    ),
    'selectorclass': TextStyle(
      color: isDark ? const Color(0xFFFFE08A) : const Color(0xFFB45309),
    ),
    'selectorid': TextStyle(
      color: isDark ? const Color(0xFFFFE08A) : const Color(0xFFB45309),
    ),
    'variable': TextStyle(
      color: isDark ? const Color(0xFFB6D5FF) : const Color(0xFF1D4ED8),
    ),
    'params': TextStyle(
      color: isDark ? const Color(0xFFB6D5FF) : const Color(0xFF1D4ED8),
    ),
    'function': TextStyle(
      color: isDark ? const Color(0xFFFFE082) : const Color(0xFFCA8A04),
    ),
    'title': TextStyle(
      color: isDark ? const Color(0xFFFFE082) : const Color(0xFFCA8A04),
    ),
    'titlefunction': TextStyle(
      color: isDark ? const Color(0xFFFFE082) : const Color(0xFFCA8A04),
    ),
    'titleclass': TextStyle(color: typeColor),
    'regexp': TextStyle(
      color: isDark ? const Color(0xFFFF9F7C) : const Color(0xFFDC2626),
    ),
    'meta': TextStyle(color: tagColor),
    'symbol': TextStyle(
      color: isDark ? const Color(0xFFC4F1A3) : const Color(0xFF2E8B57),
    ),
    'deletion': TextStyle(
      color: isDark ? const Color(0xFFFFB39B) : const Color(0xFFDC2626),
    ),
    'addition': TextStyle(
      color: isDark ? const Color(0xFFC4F1A3) : const Color(0xFF15803D),
    ),
    'link': TextStyle(color: commentColor),
    'quote': TextStyle(color: commentColor),
    'bullet': TextStyle(
      color: isDark ? const Color(0xFFFFE082) : const Color(0xFFB45309),
    ),
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.bold),
  };
}

String highlightLanguage(String language) {
  return switch (language.toLowerCase()) {
    'html' => 'xml',
    'js' => 'javascript',
    'ts' => 'typescript',
    'py' => 'python',
    'rb' => 'ruby',
    'kt' => 'kotlin',
    'sh' || 'bash' || 'shell' => 'bash',
    'c++' => 'cpp',
    'rs' => 'rust',
    'yml' => 'yaml',
    _ => language.toLowerCase(),
  };
}

List<TextSpan> highlightCode(
  String code,
  String language, {
  Map<String, TextStyle>? theme,
}) {
  final lang = highlightLanguage(language);
  final palette = theme ??
      const {
        'root': TextStyle(color: Color(0xFF1F2937)),
      };
  try {
    final result = highlight.parse(code, language: lang);
    return _spansFromNodes(result.nodes ?? [], palette);
  } catch (_) {
    // Language not supported by highlight, fall back to plain text
    return [TextSpan(text: code, style: palette['root'])];
  }
}

List<TextSpan> _spansFromNodes(
  List<Node> nodes,
  Map<String, TextStyle> theme,
) {
  return _spansFromNodesWithStyle(
    nodes,
    theme,
    theme['root'],
  );
}

List<TextSpan> _spansFromNodesWithStyle(
  List<Node> nodes,
  Map<String, TextStyle> theme,
  TextStyle? parentStyle,
) {
  final spans = <TextSpan>[];
  for (final node in nodes) {
    final nodeStyle = _resolveNodeStyle(
      node.className,
      theme,
      parentStyle ?? theme['root'],
    );
    if (node.value != null) {
      spans.add(TextSpan(
        text: node.value,
        style: nodeStyle,
      ));
    }
    if (node.children != null) {
      spans.addAll(_spansFromNodesWithStyle(node.children!, theme, nodeStyle));
    }
  }
  return spans;
}

TextStyle? _resolveNodeStyle(
  String? className,
  Map<String, TextStyle> theme,
  TextStyle? fallback,
) {
  if (className == null || className.isEmpty) return fallback;
  TextStyle? style = fallback;
  for (final token in className.split(' ')) {
    final themed = theme[token.trim()];
    if (themed != null) {
      style = style?.merge(themed) ?? themed;
    }
  }
  return style;
}

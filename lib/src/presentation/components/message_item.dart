import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../workspace/file_viewer_screen.dart';
import 'code_utils.dart';

({
  Color link,
  Color h1,
  Color h2,
  Color h3,
  Color strong,
  Color tableHead,
}) _assistantPalette(
  BuildContext context,
  bool isDark,
) {
  final tokens = context.appThemeTokens;
  final mode = context.chatColorTheme.mode;
  if (mode == ChatColorMode.theme) {
    final themeTone = Color.lerp(
      tokens.accent,
      tokens.foreground,
      isDark ? 0.18 : 0.24,
    )!;
    final quietTone = Color.lerp(
      tokens.accent,
      tokens.mutedForeground,
      isDark ? 0.28 : 0.38,
    )!;
    return (
      link: tokens.accent,
      h1: tokens.accent,
      h2: themeTone,
      h3: quietTone,
      strong:
          Color.lerp(tokens.accent, tokens.foreground, isDark ? 0.12 : 0.2)!,
      tableHead: themeTone,
    );
  }

  return (
    link: isDark ? const Color(0xFF9BBEFF) : const Color(0xFF1F4FC9),
    h1: isDark ? const Color(0xFFD2B8FF) : const Color(0xFF6A34D7),
    h2: isDark ? const Color(0xFFFFD479) : const Color(0xFFB86315),
    h3: isDark ? const Color(0xFF71E8D7) : const Color(0xFF0F766E),
    strong: isDark ? const Color(0xFFFFABC1) : const Color(0xFFBC3F72),
    tableHead: isDark ? const Color(0xFF9ED4FF) : const Color(0xFF155E75),
  );
}

String normalizeAssistantMarkdownSegment(String input) {
  final brPattern = RegExp(r'<br\s*/?>', caseSensitive: false);
  final lines = input.split('\n');
  final normalized = lines.map((line) {
    final isTableLine = line.contains('|');
    final brReplacement = isTableLine ? ' / ' : '  \n';
    final withBreaks = line.replaceAll(brPattern, brReplacement);
    return _normalizeHtmlishMarkdownLine(
      withBreaks,
      inTable: isTableLine,
    );
  }).join('\n');
  return _promoteStyledListLabels(
    _normalizeLooseStructuredSections(
      _normalizeLooseFormulaLines(
        _normalizeInlineDisplayMath(
          _normalizeBracketWrappedDisplayMath(normalized),
        )
            .replaceAll(RegExp(r'^\s*\*{3,}\s*$', multiLine: true), '')
            .replaceAll(RegExp(r'\n{3,}'), '\n\n')
            .trimRight(),
      ),
    ),
  );
}

String _normalizeBracketWrappedDisplayMath(String input) {
  final lines = input.split('\n');
  final normalizedLines = lines.map((line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith(r'[\') || !trimmed.endsWith(']')) {
      return line;
    }

    final inner = trimmed.substring(1, trimmed.length - 1);
    if (!inner.startsWith(r'\')) {
      return line;
    }

    final leading = line.substring(0, line.indexOf(trimmed));
    final trailing = line.substring(line.indexOf(trimmed) + trimmed.length);
    return '$leading\\[$inner\\]$trailing';
  });
  return normalizedLines.join('\n');
}

String _promoteStyledListLabels(String input) {
  final lines = input.split('\n');
  final promoted = <String>[];

  for (final line in lines) {
    final orderedMatch = RegExp(
      r'^\s*(\d+)\.\s+\*\*([^*\n]{2,})\*\*(.*)$',
    ).firstMatch(line);
    if (orderedMatch != null) {
      final index = orderedMatch.group(1)!;
      final label = orderedMatch.group(2)!.trim();
      final remainder = orderedMatch.group(3)!.trimLeft();
      promoted
        ..add('**$index. $label**${remainder.isEmpty ? '' : ' $remainder'}')
        ..add('');
      continue;
    }

    final bulletMatch = RegExp(
      r'^\s*[-*+]\s+\*\*([^*\n]{2,})\*\*(.*)$',
    ).firstMatch(line);
    if (bulletMatch != null) {
      final label = bulletMatch.group(1)!.trim();
      final remainder = bulletMatch.group(2)!.trimLeft();
      promoted
        ..add('**$label**${remainder.isEmpty ? '' : ' $remainder'}')
        ..add('');
      continue;
    }

    promoted.add(line);
  }

  return promoted.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
}

String _normalizeLooseStructuredSections(String input) {
  final lines = input.split('\n');
  final normalized = <String>[];

  for (var index = 0; index < lines.length; index++) {
    var line = lines[index];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      normalized.add(line);
      continue;
    }
    if (trimmed.startsWith('```') ||
        trimmed.startsWith('|') ||
        trimmed.startsWith('#') ||
        trimmed.startsWith('>')) {
      normalized.add(line);
      continue;
    }

    final bulletMatch = RegExp(r'^(\s*)[•●▪◦]\s+(.+)$').firstMatch(line);
    if (bulletMatch != null) {
      normalized.add('${bulletMatch.group(1)}- ${bulletMatch.group(2)}');
      continue;
    }

    final labeledMatch = RegExp(
      r'^(\s*)((?:[A-Z]|\d+)[.)])\s+([^:\n]{2,90}?):\s+(.+)$',
    ).firstMatch(line);
    if (labeledMatch != null) {
      final leading = labeledMatch.group(1) ?? '';
      final marker = labeledMatch.group(2) ?? '';
      final label = labeledMatch.group(3)?.trim() ?? '';
      final remainder = labeledMatch.group(4)?.trimLeft() ?? '';
      normalized.add(
        '$leading**$marker $label:** $remainder',
      );
      continue;
    }

    final nextTrimmed = index + 1 < lines.length ? lines[index + 1].trim() : '';
    if (_looksLikeLooseSectionHeading(trimmed, nextTrimmed)) {
      normalized.add('### $trimmed');
      continue;
    }

    normalized.add(line);
  }

  return normalized.join('\n');
}

String _normalizeLooseFormulaLines(String input) {
  final lines = input.split('\n');
  final normalized = <String>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('```') ||
        trimmed.startsWith('|') ||
        trimmed.startsWith('>') ||
        trimmed.startsWith(r'$$') ||
        trimmed.startsWith(r'\[') ||
        trimmed.startsWith(r'\(')) {
      normalized.add(line);
      continue;
    }

    final standaloneBoldFormula = RegExp(
      r'^\s*(?:[-*+]\s+)?\*\*([^*\n]+)\*\*\s*$',
    ).firstMatch(line);
    if (standaloneBoldFormula != null) {
      final candidate = standaloneBoldFormula.group(1)?.trim() ?? '';
      if (_looksLikePlainTextFormula(candidate)) {
        normalized.add(
          r'$$' + _normalizePlainTextFormula(candidate) + r'$$',
        );
        continue;
      }
    }

    normalized.add(line);
  }

  return normalized.join('\n');
}

bool _looksLikePlainTextFormula(String input) {
  if (input.isEmpty || !input.contains('=')) {
    return false;
  }
  if (RegExp(r'[\u0900-\u097F]').hasMatch(input)) {
    return false;
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(input)) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9_{}\^\s+\-=/().,×*]+$').hasMatch(input);
}

String _normalizePlainTextFormula(String input) {
  var normalized = input.trim();
  normalized = normalized.replaceAll('×', r' \times ');
  normalized = normalized.replaceAllMapped(
    RegExp(r'\b([A-Za-z]+)_([A-Za-z0-9]+)\b'),
    (match) => '${match.group(1)}_{${match.group(2)}}',
  );
  normalized = normalized.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  return normalized;
}

bool _looksLikeLooseSectionHeading(String line, String nextLine) {
  if (!RegExp(r'^(?:[A-Z]|\d+)[.)]\s+').hasMatch(line)) {
    return false;
  }
  if (line.contains(':')) {
    return false;
  }
  if (line.length > 90) {
    return false;
  }
  if (RegExp(r'[.!?।]$').hasMatch(line)) {
    return false;
  }
  if (nextLine.isEmpty) {
    return true;
  }
  if (nextLine.startsWith('- ') ||
      nextLine.startsWith('* ') ||
      nextLine.startsWith('• ')) {
    return true;
  }
  return !RegExp(r'^(?:[A-Z]|\d+)[.)]\s+').hasMatch(nextLine);
}

String _normalizeInlineDisplayMath(String input) {
  return input.replaceAllMapped(
    RegExp(r'\$\$([^\n$][\s\S]*?[^\n$])\$\$'),
    (match) {
      final full = match.group(0) ?? '';
      final inner = match.group(1)?.trim();
      if (inner == null || inner.isEmpty) {
        return full;
      }
      final start = match.start;
      final end = match.end;
      final hasTextBeforeOnLine = start > 0 &&
          !'\n\r'.contains(input[start - 1]) &&
          input.substring(0, start).split('\n').last.trim().isNotEmpty;
      final hasTextAfterOnLine = end < input.length &&
          !'\n\r'.contains(input[end]) &&
          input.substring(end).split('\n').first.trim().isNotEmpty;
      if (!hasTextBeforeOnLine && !hasTextAfterOnLine) {
        return full;
      }
      return r'\(' + inner + r'\)';
    },
  );
}

String _normalizeHtmlishMarkdownLine(
  String input, {
  required bool inTable,
}) {
  var normalized = input
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
      .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>');

  if (inTable) {
    normalized = normalized
        .replaceAll(
          RegExp(r'</li>\s*<li[^>]*>', caseSensitive: false),
          ' • ',
        )
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?(ul|ol)[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'(?:\s*[•/]\s*){2,}'), ' • ')
        .trim();
    normalized = normalized.replaceAll(RegExp(r'([.!?])\s*[•/]\s*$'), r'$1');
    return normalized;
  }

  normalized = normalized
      .replaceAll(
        RegExp(r'</li>\s*<li[^>]*>', caseSensitive: false),
        '\n- ',
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?(ul|ol)[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?p[^>]*>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return normalized;
}

MarkdownStyleSheet buildAssistantMarkdownStyleSheet(
  BuildContext context, {
  bool compact = false,
}) {
  final tokens = context.appThemeTokens;
  final typography = context.appTypography;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final palette = _assistantPalette(context, isDark);
  final inlineCodeSurface = Color.alphaBlend(
    tokens.accent.withValues(alpha: isDark ? 0.18 : 0.1),
    tokens.elevatedSurface,
  );
  final emphasisColor = tokens.foreground.withValues(alpha: 0.92);
  final tableOutsideColor = Color.alphaBlend(
    tokens.accent.withValues(alpha: isDark ? 0.22 : 0.14),
    tokens.mutedBorder,
  );
  final tableInsideColor = Color.alphaBlend(
    tokens.accent.withValues(alpha: isDark ? 0.12 : 0.07),
    tokens.mutedBorder,
  );
  final tableRowSurface = Color.alphaBlend(
    tokens.accent.withValues(alpha: isDark ? 0.08 : 0.05),
    tokens.panelSurface,
  );

  return MarkdownStyleSheet(
    a: typography.chatBody.copyWith(
      color: palette.link,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: palette.link.withValues(alpha: 0.45),
    ),
    p: typography.chatBody,
    pPadding: EdgeInsets.zero,
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 13.5,
      color: palette.link,
      backgroundColor: inlineCodeSurface,
    ),
    h1: typography.chatH1.copyWith(
      color: palette.h1,
      fontWeight: FontWeight.w800,
    ),
    h1Padding: EdgeInsets.only(top: compact ? 4 : 6, bottom: compact ? 8 : 12),
    h2: typography.chatH2.copyWith(
      color: palette.h2,
      fontWeight: FontWeight.w700,
    ),
    h2Padding: EdgeInsets.only(top: compact ? 4 : 6, bottom: compact ? 8 : 10),
    h3: typography.chatH3.copyWith(
      color: palette.h3,
      fontWeight: FontWeight.w700,
    ),
    h3Padding: EdgeInsets.only(top: compact ? 2 : 4, bottom: compact ? 6 : 8),
    em: typography.chatBody.copyWith(
      color: emphasisColor,
      fontStyle: FontStyle.italic,
    ),
    strong: typography.chatStrong.copyWith(
      color: palette.strong,
      fontWeight: FontWeight.w700,
    ),
    blockSpacing: compact ? 8 : 12,
    listIndent: 22,
    listBullet: typography.chatListBullet.copyWith(
      color: typography.chatBody.color ?? tokens.foreground,
      fontWeight: FontWeight.w700,
    ),
    listBulletPadding: const EdgeInsets.only(right: 8),
    tableHead: typography.chatStrong.copyWith(
      color: palette.tableHead,
      fontSize: 14.4,
      fontWeight: FontWeight.w700,
    ),
    tableBody: typography.chatBody.copyWith(
      color: tokens.foreground,
      fontSize: 14.2,
    ),
    tableHeadAlign: TextAlign.left,
    tablePadding: const EdgeInsets.only(bottom: 14),
    tableBorder: TableBorder(
      top: BorderSide(color: tableOutsideColor),
      right: BorderSide(color: tableOutsideColor),
      bottom: BorderSide(color: tableOutsideColor),
      left: BorderSide(color: tableOutsideColor),
      horizontalInside: BorderSide(color: tableInsideColor),
      verticalInside: BorderSide(color: tableInsideColor),
      borderRadius: BorderRadius.circular(18),
    ),
    tableColumnWidth: const IntrinsicColumnWidth(),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    tableCellsDecoration: BoxDecoration(
      color: tableRowSurface,
    ),
    blockquote: typography.chatBlockquote.copyWith(
      color: emphasisColor,
      height: 1.6,
    ),
    blockquoteDecoration: BoxDecoration(
      color: Color.alphaBlend(
        tokens.accent.withValues(alpha: isDark ? 0.12 : 0.08),
        tokens.elevatedSurface,
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border(
        left: BorderSide(
          color: palette.link,
          width: 4,
        ),
      ),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: tokens.elevatedSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: tokens.mutedBorder),
    ),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: tokens.mutedBorder,
          width: 1.2,
        ),
      ),
    ),
  );
}

class _MathMarkdownChunk {
  const _MathMarkdownChunk.markdown(this.content) : isDisplayMath = false;

  const _MathMarkdownChunk.displayMath(this.content) : isDisplayMath = true;

  final String content;
  final bool isDisplayMath;
}

final List<md.InlineSyntax> _assistantInlineSyntaxes = [
  _MathInlineSyntax(
    r'\\\((.+?)\\\)',
    startCharacter: 0x5C,
  ),
  _MathInlineSyntax(
    r'(?<!\$)\$([^\$\n]+?)\$(?!\$)',
    startCharacter: 0x24,
  ),
];

final Map<String, MarkdownElementBuilder> _assistantMarkdownBuilders = {
  'math-inline': _MathInlineBuilder(),
};

List<_MathMarkdownChunk> _splitMathMarkdown(String input) {
  final matches = RegExp(
    r'(\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\])',
    multiLine: true,
  ).allMatches(input);
  if (matches.isEmpty) {
    return [_MathMarkdownChunk.markdown(input)];
  }

  final chunks = <_MathMarkdownChunk>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      chunks.add(
          _MathMarkdownChunk.markdown(input.substring(cursor, match.start)));
    }
    chunks.add(
      _MathMarkdownChunk.displayMath(
        _stripMathDelimiters(match.group(0)!).trim(),
      ),
    );
    cursor = match.end;
  }
  if (cursor < input.length) {
    chunks.add(_MathMarkdownChunk.markdown(input.substring(cursor)));
  }
  return chunks.where((chunk) => chunk.content.trim().isNotEmpty).toList();
}

String _stripMathDelimiters(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith(r'$$') && trimmed.endsWith(r'$$')) {
    return trimmed.substring(2, trimmed.length - 2);
  }
  if (trimmed.startsWith(r'\[') && trimmed.endsWith(r'\]')) {
    return trimmed.substring(2, trimmed.length - 2);
  }
  if (trimmed.startsWith(r'\(') && trimmed.endsWith(r'\)')) {
    return trimmed.substring(2, trimmed.length - 2);
  }
  if (trimmed.startsWith(r'$') &&
      trimmed.endsWith(r'$') &&
      trimmed.length >= 2) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax(
    super.pattern, {
    required int startCharacter,
  }) : super(startCharacter: startCharacter);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(
      md.Element.text(
        'math-inline',
        _stripMathDelimiters(match[0]!),
      ),
    );
    return true;
  }
}

class _MathInlineBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final textStyle =
        preferredStyle ?? parentStyle ?? DefaultTextStyle.of(context).style;
    return Math.tex(
      element.textContent,
      mathStyle: MathStyle.text,
      textStyle: textStyle,
      onErrorFallback: (error) => Text(
        element.textContent,
        style: textStyle.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}

class _AssistantMarkdownSegment extends StatelessWidget {
  const _AssistantMarkdownSegment({
    required this.data,
    required this.compact,
    this.onTapLink,
  });

  final String data;
  final bool compact;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final normalizedData = normalizeAssistantMarkdownSegment(data);
    final chunks = _splitMathMarkdown(normalizedData);
    final labeledParagraphs = _splitStyledLabelParagraphs(normalizedData);
    if (labeledParagraphs != null) {
      return _LabeledParagraphGroup(
        paragraphs: labeledParagraphs,
        compact: compact,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final chunk in chunks)
          if (chunk.isDisplayMath)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _MathDisplayBlock(expression: chunk.content),
            )
          else
            MarkdownBody(
              data: chunk.content,
              selectable: false,
              styleSheet: buildAssistantMarkdownStyleSheet(
                context,
                compact: compact,
              ),
              inlineSyntaxes: _assistantInlineSyntaxes,
              builders: _assistantMarkdownBuilders,
              onTapLink: onTapLink,
            ),
      ],
    );
  }
}

List<String>? _splitStyledLabelParagraphs(String input) {
  final normalized = input.trim();
  if (normalized.isEmpty) return null;
  if (normalized.contains('| ---')) return null;
  if (normalized.contains('```')) return null;
  if (normalized.startsWith('#')) return null;
  if (normalized.startsWith('- ') || normalized.startsWith('* ')) return null;
  if (normalized.startsWith('>')) return null;

  final paragraphs =
      normalized.split(RegExp(r'\n\s*\n')).map((p) => p.trim()).toList();
  if (paragraphs.length < 2) return null;

  final labeledCount = paragraphs.where(_looksLikeLabeledParagraph).length;
  return labeledCount >= 2 ? paragraphs : null;
}

bool _looksLikeLabeledParagraph(String paragraph) {
  return RegExp(r'^\*\*[^*\n]{2,}:\*\*\s+\S').hasMatch(paragraph);
}

String _normalizeAssistantRenderEnvelope(
  String input, {
  required bool allowIncompleteMarkdown,
}) {
  var normalized =
      allowIncompleteMarkdown ? normalizeStreamingMarkdown(input) : input;

  final displayMathOpen = RegExp(r'\\\[').allMatches(normalized).length;
  final displayMathClose = RegExp(r'\\\]').allMatches(normalized).length;
  if (displayMathOpen > displayMathClose) {
    normalized = '$normalized\n\\]';
  }

  final blockMathFenceCount = RegExp(r'\$\$').allMatches(normalized).length;
  if (blockMathFenceCount.isOdd) {
    normalized = '$normalized\n\$\$';
  }

  return normalized;
}

List<String> _buildAssistantRenderSegments(
  String input, {
  required bool allowIncompleteMarkdown,
}) {
  final normalized = _normalizeAssistantRenderEnvelope(
    input,
    allowIncompleteMarkdown: allowIncompleteMarkdown,
  );
  final hasCode = normalized.contains('```');
  return (hasCode ? splitMarkdown(normalized) : [normalized])
      .map(
        (segment) => segment.startsWith('```')
            ? segment
            : normalizeAssistantMarkdownSegment(segment),
      )
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);
}

class _LabeledParagraphGroup extends StatelessWidget {
  const _LabeledParagraphGroup({
    required this.paragraphs,
    required this.compact,
  });

  final List<String> paragraphs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseStyle = buildAssistantMarkdownStyleSheet(
      context,
      compact: compact,
    );
    final palette = _labeledParagraphPalette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == paragraphs.length - 1
                  ? 0
                  : compact
                      ? 12
                      : 18,
            ),
            child: MarkdownBody(
              data: paragraphs[i],
              selectable: false,
              styleSheet: baseStyle.copyWith(
                strong: baseStyle.strong?.copyWith(
                  color: palette[i % palette.length],
                ),
                pPadding: EdgeInsets.zero,
              ),
              inlineSyntaxes: _assistantInlineSyntaxes,
              builders: _assistantMarkdownBuilders,
            ),
          ),
      ],
    );
  }
}

List<Color> _labeledParagraphPalette(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return const [
      Color(0xFFFFA5BE),
      Color(0xFF72E6D7),
      Color(0xFFF6D57C),
      Color(0xFFAEBBFF),
    ];
  }

  return const [
    Color(0xFFB83B6E),
    Color(0xFF0F766E),
    Color(0xFFB16A13),
    Color(0xFF4F46E5),
  ];
}

class _MathDisplayBlock extends StatelessWidget {
  const _MathDisplayBlock({required this.expression});

  final String expression;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final style = context.appTypography.chatBody.copyWith(
      color: tokens.foreground,
      fontSize: 17,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          expression,
          mathStyle: MathStyle.display,
          textStyle: style,
          onErrorFallback: (error) => Text(
            expression,
            style: style.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}

enum _StudentTutorSectionType {
  directAnswer,
  simpleExplanation,
  keyPoints,
  extraSection,
  example,
  summary,
}

class _StudentTutorSectionSpec {
  const _StudentTutorSectionSpec({
    required this.id,
    required this.type,
    required this.emoji,
    required this.title,
    required this.color,
    required this.aliases,
  });

  final String id;
  final _StudentTutorSectionType type;
  final String emoji;
  final String title;
  final Color color;
  final List<String> aliases;

  bool get isBrief =>
      type == _StudentTutorSectionType.directAnswer ||
      type == _StudentTutorSectionType.summary;
}

class _StudentTutorSection {
  const _StudentTutorSection({
    required this.spec,
    required this.content,
  });

  final _StudentTutorSectionSpec spec;
  final String content;
}

class _StudentTutorNotes {
  const _StudentTutorNotes({required this.sections});

  final List<_StudentTutorSection> sections;
}

class _StudentTutorHeaderMatch {
  const _StudentTutorHeaderMatch({
    required this.inlineContent,
  });

  final String inlineContent;
}

const List<_StudentTutorSectionSpec> _studentTutorSectionSpecs = [
  _StudentTutorSectionSpec(
    id: 'direct-answer',
    type: _StudentTutorSectionType.directAnswer,
    emoji: '🎯',
    title: 'Direct Answer',
    color: Color(0xFF2563EB),
    aliases: ['direct answer', 'answer'],
  ),
  _StudentTutorSectionSpec(
    id: 'simple-explanation',
    type: _StudentTutorSectionType.simpleExplanation,
    emoji: '📖',
    title: 'Simple Explanation',
    color: Color(0xFF16A34A),
    aliases: ['simple explanation', 'explanation'],
  ),
  _StudentTutorSectionSpec(
    id: 'key-points',
    type: _StudentTutorSectionType.keyPoints,
    emoji: '📌',
    title: 'Key Points',
    color: Color(0xFF9333EA),
    aliases: ['key points', 'points'],
  ),
  _StudentTutorSectionSpec(
    id: 'extra-section',
    type: _StudentTutorSectionType.extraSection,
    emoji: '📊',
    title: 'Extra Section',
    color: Color(0xFFEA580C),
    aliases: ['extra section', 'extra'],
  ),
  _StudentTutorSectionSpec(
    id: 'example',
    type: _StudentTutorSectionType.example,
    emoji: '📖',
    title: 'Example',
    color: Color(0xFFDB2777),
    aliases: ['example'],
  ),
  _StudentTutorSectionSpec(
    id: 'summary',
    type: _StudentTutorSectionType.summary,
    emoji: '✨',
    title: 'Summary',
    color: Color(0xFF0F172A),
    aliases: ['summary'],
  ),
];

_StudentTutorNotes? _tryParseStudentTutorNotes(String input) {
  final normalizedInput = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalizedInput.split('\n');
  final sections = <_StudentTutorSection>[];
  final buffer = <String>[];
  var expectedIndex = 0;

  for (final rawLine in lines) {
    final line = rawLine.trimRight();
    final trimmed = line.trim();

    if (expectedIndex == 0 && (trimmed.isEmpty || trimmed == '---')) {
      continue;
    }

    if (expectedIndex < _studentTutorSectionSpecs.length) {
      final header = _matchStudentTutorHeader(
        line,
        _studentTutorSectionSpecs[expectedIndex],
      );
      if (header != null) {
        if (expectedIndex > 0) {
          final previousContent = _normalizeStudentTutorSectionContent(buffer);
          if (previousContent.isEmpty) return null;
          sections.add(
            _StudentTutorSection(
              spec: _studentTutorSectionSpecs[expectedIndex - 1],
              content: previousContent,
            ),
          );
          buffer.clear();
        }
        if (header.inlineContent.isNotEmpty) {
          buffer.add(header.inlineContent);
        }
        expectedIndex += 1;
        continue;
      }
    }

    if (expectedIndex == 0) {
      return null;
    }

    if (trimmed == '---') {
      continue;
    }
    buffer.add(rawLine);
  }

  if (expectedIndex != _studentTutorSectionSpecs.length) {
    return null;
  }

  final lastContent = _normalizeStudentTutorSectionContent(buffer);
  if (lastContent.isEmpty) return null;
  sections.add(
    _StudentTutorSection(
      spec: _studentTutorSectionSpecs.last,
      content: lastContent,
    ),
  );

  if (sections.length != _studentTutorSectionSpecs.length) {
    return null;
  }

  return _StudentTutorNotes(sections: sections);
}

_StudentTutorHeaderMatch? _matchStudentTutorHeader(
  String line,
  _StudentTutorSectionSpec spec,
) {
  var candidate = line.trim();
  if (candidate.isEmpty) return null;

  candidate = candidate
      .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
      .replaceFirst(RegExp(r'^[>\-\*\s]+'), '')
      .replaceAll('**', '')
      .replaceAll('__', '')
      .trim();

  if (!candidate.startsWith(spec.emoji)) {
    return null;
  }

  var remainder = candidate.substring(spec.emoji.length).trim();
  if (remainder.isEmpty) return null;

  remainder = remainder.replaceAll(RegExp(r'\s+'), ' ').trim();
  final withoutParentheticals =
      remainder.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

  var labelSource = withoutParentheticals;
  var inlineContent = '';
  final colonIndex = withoutParentheticals.indexOf(':');
  if (colonIndex >= 0) {
    labelSource = withoutParentheticals.substring(0, colonIndex).trim();
    inlineContent = withoutParentheticals.substring(colonIndex + 1).trimLeft();
  }

  final normalizedLabel = _normalizeStudentTutorLabel(labelSource);
  final matchesAlias = spec.aliases.any(
    (alias) =>
        normalizedLabel == alias ||
        normalizedLabel.startsWith('$alias ') ||
        normalizedLabel.endsWith(' $alias'),
  );
  if (!matchesAlias) {
    return null;
  }

  return _StudentTutorHeaderMatch(inlineContent: inlineContent.trimRight());
}

String _normalizeStudentTutorLabel(String input) {
  return input
      .replaceFirst(RegExp(r'^\d+\.\s*'), '')
      .replaceAll(RegExp(r'[^a-zA-Z ]'), ' ')
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _normalizeStudentTutorSectionContent(List<String> lines) {
  final joined = lines.join('\n').trim();
  return joined.replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

class _StudentTutorNotesView extends StatelessWidget {
  const _StudentTutorNotesView({
    required this.notes,
    this.onOpenSandbox,
  });

  final _StudentTutorNotes notes;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in notes.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _StudentTutorSectionCard(
              section: section,
              onOpenSandbox: onOpenSandbox,
            ),
          ),
      ],
    );
  }
}

class _StudentTutorSectionCard extends StatelessWidget {
  const _StudentTutorSectionCard({
    required this.section,
    this.onOpenSandbox,
  });

  final _StudentTutorSection section;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final theme = Theme.of(context);
    final typography = context.appTypography;
    final isDark = theme.brightness == Brightness.dark;
    final accent = _studentTutorAccentColor(
      context,
      section: section,
      isDark: isDark,
    );
    final surface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.18 : 0.07),
      tokens.panelSurface,
    );
    final headerSurface = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.3 : 0.14),
      tokens.elevatedSurface,
    );
    final borderColor = accent.withValues(alpha: isDark ? 0.45 : 0.22);

    return Container(
      key: ValueKey('student-tutor-card-${section.spec.id}'),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: headerSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),
            child: Row(
              children: [
                Text(
                  section.spec.emoji,
                  style: typography.chatH3.copyWith(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    section.spec.title,
                    style: typography.chatStrong.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              section.spec.isBrief ? 10 : 12,
              14,
              section.spec.isBrief ? 12 : 14,
            ),
            child: _StudentTutorSectionBody(
              content: section.content,
              compact: section.spec.isBrief,
              onOpenSandbox: onOpenSandbox,
            ),
          ),
        ],
      ),
    );
  }
}

Color _studentTutorAccentColor(
  BuildContext context, {
  required _StudentTutorSection section,
  required bool isDark,
}) {
  if (context.chatColorTheme.mode == ChatColorMode.colorful) {
    return section.spec.color;
  }

  final tokens = context.appThemeTokens;
  final tone = switch (section.spec.type) {
    _StudentTutorSectionType.directAnswer => isDark ? 0.08 : 0.16,
    _StudentTutorSectionType.simpleExplanation => isDark ? 0.14 : 0.22,
    _StudentTutorSectionType.keyPoints => isDark ? 0.2 : 0.28,
    _StudentTutorSectionType.extraSection => isDark ? 0.18 : 0.26,
    _StudentTutorSectionType.example => isDark ? 0.12 : 0.2,
    _StudentTutorSectionType.summary => isDark ? 0.24 : 0.32,
  };
  return Color.lerp(tokens.accent, tokens.foreground, tone)!;
}

class _StudentTutorSectionBody extends StatelessWidget {
  const _StudentTutorSectionBody({
    required this.content,
    required this.compact,
    this.onOpenSandbox,
  });

  final String content;
  final bool compact;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    final segments = splitMarkdown(content)
        .map(
          (segment) => segment.startsWith('```')
              ? segment
              : normalizeAssistantMarkdownSegment(segment),
        )
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments)
          if (segment.startsWith('```'))
            CodePanel(
              codeBlock: segment,
              onOpenSandbox: onOpenSandbox == null
                  ? null
                  : (code, language) => onOpenSandbox!(code, language),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AssistantMarkdownSegment(
                data: segment,
                compact: compact,
              ),
            ),
      ],
    );
  }
}

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({
    super.key,
    required this.message,
    this.onEdit,
  });

  final ChatMessage message;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.82;
    final tokens = context.appThemeTokens;
    final visibleContent = _visibleUserMessageContent(message);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 48, bottom: 14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showActions(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tokens.selectedSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.mutedBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.attachments.isNotEmpty) ...[
                    _UserMessageAttachmentStrip(
                      attachments: message.attachments,
                      onEdit: onEdit,
                    ),
                    if (visibleContent.isNotEmpty) const SizedBox(height: 10),
                  ],
                  if (visibleContent.isNotEmpty)
                    Text(
                      visibleContent,
                      style: context.appTypography.chatBody,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final localizations = MaterialLocalizations.of(context);
    final sentAt = message.createdAt.toLocal();
    final sentTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(sentAt),
      alwaysUse24HourFormat:
          MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false,
    );
    final now = DateTime.now();
    final isToday = sentAt.year == now.year &&
        sentAt.month == now.month &&
        sentAt.day == now.day;
    final sentDateLabel = isToday
        ? 'Today'
        : '${localizations.formatShortMonthDay(sentAt)} ${sentAt.year}';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appThemeTokens.modalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        final tokens = sheetContext.appThemeTokens;
        final typography = sheetContext.appTypography;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onEdit != null)
                  _UserMessageActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      onEdit?.call();
                    },
                  ),
                _UserMessageActionTile(
                  icon: Icons.copy_rounded,
                  label: 'Copy text',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: _visibleUserMessageContent(message)),
                    );
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Message copied'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: context.appThemeTokens.modalSurface,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.schedule_rounded,
                    color: tokens.subtleForeground,
                    size: 20,
                  ),
                  title: Text(
                    sentTime,
                    style: typography.chatBody.copyWith(
                      color: tokens.foreground,
                    ),
                  ),
                  subtitle: Text(
                    sentDateLabel,
                    style: typography.chatMeta.copyWith(
                      color: tokens.subtleForeground,
                    ),
                  ),
                  enabled: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserMessageAttachmentStrip extends StatelessWidget {
  const _UserMessageAttachmentStrip({
    required this.attachments,
    this.onEdit,
  });

  final List<ChatAttachment> attachments;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final decoded = attachments
        .map(_UserMessageDecodedAttachment.fromAttachment)
        .whereType<_UserMessageDecodedAttachment>()
        .toList();

    if (decoded.isEmpty) {
      return const SizedBox.shrink();
    }

    final crossAxisCount = decoded.length == 1 ? 1 : 2;
    final itemCount = decoded.length > 4 ? 4 : decoded.length;

    return SizedBox(
      width: decoded.length == 1 ? 180 : 220,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: decoded.length == 1 ? 1.25 : 1,
        ),
        itemBuilder: (context, index) {
          final item = decoded[index];
          final remaining = decoded.length - itemCount;
          return GestureDetector(
            key: ValueKey(
              item.attachment.inlineDataBase64 ?? item.attachment.name,
            ),
            onTap: () {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black87,
                builder: (_) => _ImageGalleryDialog(
                  items: decoded,
                  initialIndex: index,
                  onEdit: onEdit,
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image(
                    image: item.imageProvider,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                if (remaining > 0 && index == itemCount - 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '+$remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({
    required this.items,
    required this.initialIndex,
    this.onEdit,
  });

  final List<_UserMessageDecodedAttachment> items;
  final int initialIndex;
  final VoidCallback? onEdit;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (value) => setState(() => _currentIndex = value),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Center(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image(
                      image: item.imageProvider,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.items[_currentIndex].attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.onEdit != null)
                    IconButton(
                      tooltip: 'Edit message',
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onEdit?.call();
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserMessageDecodedAttachment {
  const _UserMessageDecodedAttachment({
    required this.attachment,
    required this.bytes,
    required this.imageProvider,
  });

  final ChatAttachment attachment;
  final Uint8List bytes;
  final MemoryImage imageProvider;

  static _UserMessageDecodedAttachment? fromAttachment(
    ChatAttachment attachment,
  ) {
    if (!attachment.hasInlineData) {
      return null;
    }

    final inlineData = attachment.inlineDataBase64!.trim();
    if (inlineData.isEmpty) {
      return null;
    }

    try {
      final bytes = _UserMessageAttachmentImageCache.bytesFor(inlineData);
      return _UserMessageDecodedAttachment(
        attachment: attachment,
        bytes: bytes,
        imageProvider: _UserMessageAttachmentImageCache.providerFor(
          inlineData,
          bytes,
        ),
      );
    } on FormatException {
      return null;
    }
  }
}

class _UserMessageAttachmentImageCache {
  static final Map<String, Uint8List> _bytesCache = <String, Uint8List>{};
  static final Map<String, MemoryImage> _providerCache =
      <String, MemoryImage>{};

  static Uint8List bytesFor(String inlineData) {
    return _bytesCache.putIfAbsent(inlineData, () => base64Decode(inlineData));
  }

  static MemoryImage providerFor(String inlineData, Uint8List bytes) {
    return _providerCache.putIfAbsent(
      inlineData,
      () => MemoryImage(bytes),
    );
  }
}

String _visibleUserMessageContent(ChatMessage message) {
  final content = message.content.trimRight();
  if (content.isEmpty || message.attachments.isEmpty) {
    return content;
  }

  final lines = content.split('\n');
  final attachmentHeaderIndex = lines.lastIndexWhere(
    (line) => line.trim() == 'Attachments:',
  );
  if (attachmentHeaderIndex == -1 ||
      attachmentHeaderIndex == lines.length - 1) {
    return content;
  }

  final trailingLines = lines
      .sublist(attachmentHeaderIndex + 1)
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (trailingLines.isEmpty ||
      trailingLines.any((line) => !line.trimLeft().startsWith('- '))) {
    return content;
  }

  return lines.sublist(0, attachmentHeaderIndex).join('\n').trimRight();
}

class _UserMessageActionTile extends StatelessWidget {
  const _UserMessageActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Icon(icon, color: tokens.foreground, size: 20),
      title: Text(
        label,
        style: typography.chatBody.copyWith(color: tokens.foreground),
      ),
      onTap: onTap,
    );
  }
}

class AssistantMessageCard extends StatelessWidget {
  const AssistantMessageCard({
    super.key,
    required this.message,
    this.isGenerating = false,
    this.isWaitingForResponse = false,
    this.onCopy,
    this.onRetry,
    this.onPreviewHtml,
    this.onDownloadHtml,
    this.onOpenSandbox,
    this.onThumbUp,
    this.onThumbDown,
  });

  final ChatMessage message;
  final bool isGenerating;
  final bool isWaitingForResponse;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onPreviewHtml;
  final ValueChanged<String>? onDownloadHtml;
  final void Function(String code, String language)? onOpenSandbox;
  final VoidCallback? onThumbUp;
  final VoidCallback? onThumbDown;

  @override
  Widget build(BuildContext context) {
    if (isGenerating) {
      final thinkingPreview = _parseAssistantThinkingEnvelope(
        message.content,
        allowIncomplete: true,
      );
      return _AssistantBubbleShell(
        child: isWaitingForResponse || message.content.trim().isEmpty
            ? const _ThinkingBubbleContent()
            : thinkingPreview != null
                ? _AssistantStreamingThinkingPreview(
                    envelope: thinkingPreview,
                    onOpenSandbox: onOpenSandbox,
                  )
                : _TypingBubbleText(
                    text: message.content,
                    onOpenSandbox: onOpenSandbox,
                  ),
      );
    }

    final thinkingEnvelope = _parseAssistantThinkingEnvelope(message.content);
    final messageBody = thinkingEnvelope != null
        ? _AssistantThinkingMessageBody(
            envelope: thinkingEnvelope,
            onOpenSandbox: onOpenSandbox,
          )
        : _AssistantMessageBody(
            content: message.content,
            onOpenSandbox: onOpenSandbox,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        messageBody,
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: _AssistantActionRow(
            feedback: message.feedback,
            onThumbUp: onThumbUp,
            onThumbDown: onThumbDown,
            onRetry: onRetry,
            onCopy: onCopy,
          ),
        ),
      ],
    );
  }
}

class _AssistantMessageBody extends StatelessWidget {
  const _AssistantMessageBody({
    required this.content,
    this.onOpenSandbox,
  });

  final String content;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    final studentTutorNotes = _tryParseStudentTutorNotes(content);
    if (studentTutorNotes != null) {
      return _AssistantBubbleShell(
        child: _StudentTutorNotesView(
          notes: studentTutorNotes,
          onOpenSandbox: onOpenSandbox,
        ),
      );
    }

    final segments = _buildAssistantRenderSegments(
      content,
      allowIncompleteMarkdown: false,
    );
    final firstCodeBlock = extractFirstCodeBlock(content);

    DetectedFile? detectedFile;
    if (firstCodeBlock != null) {
      detectedFile = detectFileFromCodeBlock(
        firstCodeBlock.code,
        firstCodeBlock.language,
      );
    }

    if (detectedFile != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: _FileCardWidget(
          file: detectedFile,
          onTap: () => _openFileViewer(context, detectedFile!),
          onCopy: () {
            Clipboard.setData(ClipboardData(text: detectedFile!.code));
          },
        ),
      );
    }

    return _AssistantBubbleShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final segment in segments) ...[
            if (segment.startsWith('```'))
              CodePanel(
                codeBlock: segment,
                onOpenSandbox: onOpenSandbox == null
                    ? null
                    : (code, language) => onOpenSandbox!(code, language),
              )
            else if (segment.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AssistantMarkdownSegment(
                  data: segment,
                  compact: false,
                  onTapLink: (text, href, title) {
                    if (href == null || href.isEmpty) return;
                    Clipboard.setData(ClipboardData(text: href));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard'),
                      ),
                    );
                  },
                ),
              ),
          ],
          if (firstCodeBlock != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openFileViewer(
                    context,
                    DetectedFile(
                      fileName: 'code.${firstCodeBlock.language}',
                      language: firstCodeBlock.language,
                      code: firstCodeBlock.code,
                      isLarge: false,
                    ),
                  ),
                  icon: const Icon(Icons.code_rounded, size: 16),
                  label: const Text('Open in Sandbox'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openFileViewer(BuildContext context, DetectedFile file) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FileViewerScreen(
          fileName: file.fileName,
          language: file.language,
          code: file.code,
        ),
      ),
    );
  }
}

class _AssistantThinkingMessageBody extends StatelessWidget {
  const _AssistantThinkingMessageBody({
    required this.envelope,
    this.onOpenSandbox,
  });

  final _AssistantThinkingEnvelope envelope;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssistantBubbleShell(
          child: _AssistantThinkingCard(
            reasoning: envelope.reasoning,
            isStreaming: false,
          ),
        ),
        if (envelope.answer.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _AssistantMessageBody(
            content: envelope.answer,
            onOpenSandbox: onOpenSandbox,
          ),
        ],
      ],
    );
  }
}

class _AssistantStreamingThinkingPreview extends StatelessWidget {
  const _AssistantStreamingThinkingPreview({
    required this.envelope,
    this.onOpenSandbox,
  });

  final _AssistantThinkingEnvelope envelope;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AssistantThinkingCard(
          reasoning: envelope.reasoning,
          isStreaming: true,
        ),
        if (envelope.answer.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _TypingBubbleText(
            text: envelope.answer,
            onOpenSandbox: onOpenSandbox,
          ),
        ],
      ],
    );
  }
}

class _AssistantThinkingEnvelope {
  const _AssistantThinkingEnvelope({
    required this.reasoning,
    required this.answer,
    required this.isComplete,
  });

  final String reasoning;
  final String answer;
  final bool isComplete;
}

_AssistantThinkingEnvelope? _parseAssistantThinkingEnvelope(
  String input, {
  bool allowIncomplete = false,
}) {
  if (input.trim().isEmpty) {
    return null;
  }

  final openMatch = RegExp(
    r'<(think|thinking|reasoning)\b[^>]*>',
    caseSensitive: false,
  ).firstMatch(input);
  if (openMatch == null) {
    return null;
  }

  final tag = openMatch.group(1)!;
  final closingPattern = RegExp(
    '</$tag\\s*>',
    caseSensitive: false,
  );
  final trailingInput = input.substring(openMatch.end);
  final closingMatch = closingPattern.firstMatch(trailingInput);
  final hasClosingTag = closingMatch != null;
  if (!allowIncomplete && !hasClosingTag) {
    return null;
  }

  final reasoningEnd =
      hasClosingTag ? openMatch.end + closingMatch.start : input.length;
  final reasoning = input.substring(openMatch.end, reasoningEnd).trim();
  if (reasoning.isEmpty) {
    return null;
  }

  final closingTagEnd =
      hasClosingTag ? openMatch.end + closingMatch.end : input.length;
  final before = input.substring(0, openMatch.start).trim();
  final after = input.substring(closingTagEnd).trim();
  final leakedReasoningPrefix =
      before.isNotEmpty && _looksLikeReasoningLeak(before) ? before : null;
  final answerParts = <String>[
    if (before.isNotEmpty && leakedReasoningPrefix == null) before,
    if (after.isNotEmpty) after,
  ];

  return _AssistantThinkingEnvelope(
    reasoning: leakedReasoningPrefix == null
        ? reasoning
        : '$leakedReasoningPrefix\n\n$reasoning',
    answer: answerParts.join('\n\n'),
    isComplete: hasClosingTag,
  );
}

bool _looksLikeReasoningLeak(String input) {
  final normalized = input.trim();
  if (normalized.isEmpty || normalized.length > 600) {
    return false;
  }
  final lowered = normalized.toLowerCase();
  const patterns = <String>[
    'user asks',
    'the user asks',
    'the user wants',
    'the user is asking',
    'need to',
    'i need to',
    'i should',
    'let me',
    'we need to',
    'provide the',
    'keep it concise',
    'answer in',
    'respond with',
  ];
  return patterns.any(lowered.contains);
}

class _AssistantThinkingCard extends StatefulWidget {
  const _AssistantThinkingCard({
    required this.reasoning,
    required this.isStreaming,
  });

  final String reasoning;
  final bool isStreaming;

  @override
  State<_AssistantThinkingCard> createState() => _AssistantThinkingCardState();
}

class _AssistantThinkingCardState extends State<_AssistantThinkingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('assistant-thinking-card'),
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChatAnimatedIcon(
                      size: widget.isStreaming ? 22 : 20,
                      animate: widget.isStreaming,
                    ),
                    const SizedBox(width: 8),
                    _ThinkingLabel(
                      animate: widget.isStreaming,
                      style: typography.chatStrong.copyWith(
                        color: tokens.foreground,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.2,
                        letterSpacing: 0.08,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: tokens.subtleForeground,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topLeft,
                  child: _expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8, left: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 2,
                                margin:
                                    const EdgeInsets.only(top: 2, right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      tokens.accent.withValues(alpha: 0.28),
                                      tokens.accent.withValues(alpha: 0.06),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Opacity(
                                  opacity: widget.isStreaming ? 0.66 : 0.58,
                                  child: DefaultTextStyle.merge(
                                    style: typography.chatMeta.copyWith(
                                      color: tokens.subtleForeground,
                                      height: 1.5,
                                      fontSize: 11.9,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.08,
                                    ),
                                    child: widget.isStreaming
                                        ? _TypingBubbleText(
                                            text: widget.reasoning,
                                          )
                                        : _AssistantMarkdownSegment(
                                            data:
                                                normalizeAssistantMarkdownSegment(
                                              widget.reasoning,
                                            ),
                                            compact: true,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatAnimatedIcon extends StatelessWidget {
  const _ChatAnimatedIcon({
    this.size = 20,
    this.animate = true,
  });

  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return RepaintBoundary(
      child: Opacity(
        opacity: animate ? 0.96 : 0.82,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(tokens.foreground, BlendMode.srcIn),
          child: SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/animations/lottieflow-chat-17-10-000000-easey.json',
              repeat: animate,
              animate: animate,
              frameRate: FrameRate.max,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingLabel extends StatefulWidget {
  const _ThinkingLabel({
    required this.animate,
    required this.style,
  });

  final bool animate;
  final TextStyle style;

  @override
  State<_ThinkingLabel> createState() => _ThinkingLabelState();
}

class _ThinkingLabelState extends State<_ThinkingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _ThinkingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) {
      return;
    }
    if (widget.animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Text('Thinking', style: widget.style);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        final color = Color.lerp(
          widget.style.color?.withValues(alpha: 0.58),
          widget.style.color,
          t,
        );
        return Text(
          'Thinking',
          style: widget.style.copyWith(
            color: color,
            letterSpacing: 0.08 + (0.16 * (1 - t)),
          ),
        );
      },
    );
  }
}

class _AssistantBubbleShell extends StatelessWidget {
  const _AssistantBubbleShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _FileCardWidget extends StatelessWidget {
  const _FileCardWidget({
    required this.file,
    required this.onTap,
    required this.onCopy,
  });

  final DetectedFile file;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    final lineCount = '\n'.allMatches(file.code).length + 1;
    final icon = fileIcon(file.language);
    final iconColor = fileIconColor(file.language);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.elevatedSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.fileName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.chipSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          file.language.toUpperCase(),
                          style: TextStyle(
                            color: tokens.mutedForeground,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$lineCount lines',
                        style: typography.chatMeta.copyWith(
                          color: tokens.subtleForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: tokens.subtleForeground,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: tokens.subtleForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantActionRow extends StatelessWidget {
  const _AssistantActionRow({
    required this.feedback,
    this.onThumbUp,
    this.onThumbDown,
    this.onRetry,
    this.onCopy,
  });

  final MessageFeedback? feedback;
  final VoidCallback? onThumbUp;
  final VoidCallback? onThumbDown;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _ActionChip(
          onTap: onThumbUp,
          icon: feedback == MessageFeedback.up
              ? Icons.thumb_up_alt_rounded
              : Icons.thumb_up_alt_outlined,
          color:
              feedback == MessageFeedback.up ? const Color(0xFF4CF086) : null,
        ),
        _ActionChip(
          onTap: onThumbDown,
          icon: feedback == MessageFeedback.down
              ? Icons.thumb_down_alt_rounded
              : Icons.thumb_down_alt_outlined,
          color:
              feedback == MessageFeedback.down ? const Color(0xFFFFB289) : null,
        ),
        _ActionChip(
          onTap: onRetry,
          icon: Icons.refresh_rounded,
        ),
        _ActionChip(
          onTap: onCopy,
          icon: Icons.copy_all_outlined,
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: color ?? tokens.subtleForeground,
        ),
      ),
    );
  }
}

class _ThinkingBubbleContent extends StatelessWidget {
  const _ThinkingBubbleContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _ChatAnimatedIcon(
          size: 20,
          animate: true,
        ),
      ),
    );
  }
}

class _StreamingTextParts {
  const _StreamingTextParts({
    required this.stable,
    required this.softFade,
    required this.deepFade,
  });

  final String stable;
  final String softFade;
  final String deepFade;

  bool get hasFade => softFade.isNotEmpty || deepFade.isNotEmpty;
}

bool _looksLikeStreamingRichContent(String input) {
  return looksLikeRichMarkdown(input) ||
      input.contains(r'$$') ||
      input.contains('\\[') ||
      input.contains('\\(') ||
      input.contains('\\boxed');
}

String _normalizeStreamingAssistantPreview(String input) {
  return _normalizeAssistantRenderEnvelope(
    input,
    allowIncompleteMarkdown: true,
  );
}

_StreamingTextParts _splitStreamingTextParts(String text) {
  if (text.isEmpty) {
    return const _StreamingTextParts(
      stable: '',
      softFade: '',
      deepFade: '',
    );
  }

  final trimmedRight = text.trimRight();
  final trailingWhitespace = text.substring(trimmedRight.length);
  if (trimmedRight.isEmpty) {
    return _StreamingTextParts(stable: text, softFade: '', deepFade: '');
  }

  final wordMatches = RegExp(r'\S+').allMatches(trimmedRight).toList();
  if (wordMatches.isEmpty) {
    return _StreamingTextParts(
      stable: trimmedRight,
      softFade: '',
      deepFade: trailingWhitespace,
    );
  }

  if (wordMatches.length < 4 || trimmedRight.length < 24) {
    return _StreamingTextParts(
      stable: text,
      softFade: '',
      deepFade: '',
    );
  }

  final deepFadeWordCount = wordMatches.length >= 2 ? 2 : 1;
  final softFadeWordCount = wordMatches.length >= 5 ? 5 : wordMatches.length;
  var softFadeStart = wordMatches[wordMatches.length - softFadeWordCount].start;
  var deepFadeStart = wordMatches[wordMatches.length - deepFadeWordCount].start;

  final maxSoftWindow = trimmedRight.length > 42 ? trimmedRight.length - 42 : 0;
  final maxDeepWindow = trimmedRight.length > 18 ? trimmedRight.length - 18 : 0;
  if (softFadeStart < maxSoftWindow) {
    softFadeStart = maxSoftWindow;
  }
  if (deepFadeStart < maxDeepWindow) {
    deepFadeStart = maxDeepWindow;
  }
  if (deepFadeStart < softFadeStart) {
    deepFadeStart = softFadeStart;
  }

  if (softFadeStart < 10) {
    return _StreamingTextParts(
      stable: text,
      softFade: '',
      deepFade: '',
    );
  }

  return _StreamingTextParts(
    stable: trimmedRight.substring(0, softFadeStart),
    softFade: trimmedRight.substring(softFadeStart, deepFadeStart),
    deepFade: trimmedRight.substring(deepFadeStart) + trailingWhitespace,
  );
}

/// Lightweight streaming text widget with a broader trailing fade reveal.
/// Keeps streaming cheap while avoiding provider-speed-dependent jumps.
class _TypingBubbleText extends StatefulWidget {
  const _TypingBubbleText({
    required this.text,
    this.onOpenSandbox,
  });

  final String text;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  State<_TypingBubbleText> createState() => _TypingBubbleTextState();
}

class _TypingBubbleTextState extends State<_TypingBubbleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tailFadeController;

  @override
  void initState() {
    super.initState();
    _tailFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _TypingBubbleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == oldWidget.text || widget.text.isEmpty) return;

    final nextText = normalizeAssistantMarkdownSegment(widget.text);
    final nextParts = _splitStreamingTextParts(nextText);
    final isAppendUpdate = widget.text.startsWith(oldWidget.text);

    if (!nextParts.hasFade || !isAppendUpdate) {
      _tailFadeController.value = 1;
      return;
    }

    _tailFadeController.forward(from: 0.58);
  }

  @override
  void dispose() {
    _tailFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawText = widget.text;
    final previewText = _normalizeStreamingAssistantPreview(rawText);
    final studentTutorNotes = _tryParseStudentTutorNotes(previewText);
    if (studentTutorNotes != null) {
      return _StudentTutorNotesView(
        notes: studentTutorNotes,
        onOpenSandbox: widget.onOpenSandbox,
      );
    }
    final hasCode = previewText.contains('```');
    final shouldRenderRich = hasCode || _looksLikeStreamingRichContent(rawText);
    final text = shouldRenderRich
        ? previewText
        : normalizeAssistantMarkdownSegment(rawText);
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;

    if (shouldRenderRich) {
      final segments = _buildAssistantRenderSegments(
        rawText,
        allowIncompleteMarkdown: true,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final segment in segments)
            if (segment.startsWith('```'))
              CodePanel(
                codeBlock: segment,
                onOpenSandbox: widget.onOpenSandbox == null
                    ? null
                    : (code, language) => widget.onOpenSandbox!(code, language),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AssistantMarkdownSegment(
                  data: segment,
                  compact: true,
                ),
              ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: _tailFadeController,
      builder: (context, _) {
        final parts = _splitStreamingTextParts(text);
        final baseStyle = typography.chatTyping;
        final baseColor = baseStyle.color ?? tokens.foreground;
        final fadeProgress =
            Curves.easeOutQuart.transform(_tailFadeController.value);
        final softFadeColor = baseColor.withValues(
          alpha: 0.72 + (fadeProgress * 0.28),
        );
        final deepFadeColor = baseColor.withValues(
          alpha: 0.46 + (fadeProgress * 0.54),
        );

        final children = <InlineSpan>[
          if (parts.stable.isNotEmpty)
            TextSpan(
              text: parts.stable,
              style: baseStyle,
            ),
          if (parts.softFade.isNotEmpty)
            TextSpan(
              text: parts.softFade,
              style: baseStyle.copyWith(color: softFadeColor),
            ),
          if (parts.deepFade.isNotEmpty)
            TextSpan(
              text: parts.deepFade,
              style: baseStyle.copyWith(color: deepFadeColor),
            ),
        ];

        if (children.isEmpty) {
          children.add(
            TextSpan(
              text: text,
              style: baseStyle,
            ),
          );
        }

        return Text.rich(
          TextSpan(children: children),
        );
      },
    );
  }
}

class _InlineTypingDots extends StatefulWidget {
  const _InlineTypingDots();

  @override
  State<_InlineTypingDots> createState() => _InlineTypingDotsState();
}

class _InlineTypingDotsState extends State<_InlineTypingDots> {
  @override
  Widget build(BuildContext context) {
    return const _ChatAnimatedIcon(size: 20);
  }
}

class AssistantGenerating extends StatelessWidget {
  const AssistantGenerating({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: TypingPill(),
    );
  }
}

class TypingPill extends StatefulWidget {
  const TypingPill({super.key});

  @override
  State<TypingPill> createState() => _TypingPillState();
}

class _TypingPillState extends State<TypingPill> {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: _ChatAnimatedIcon(size: 22),
    );
  }
}

class AnimatedMessageEntry extends StatelessWidget {
  const AnimatedMessageEntry({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, widgetChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: widgetChild,
          ),
        );
      },
      child: child,
    );
  }
}

class ScrollToBottomFab extends StatelessWidget {
  const ScrollToBottomFab({
    super.key,
    required this.visible,
    required this.onTap,
  });

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: FloatingActionButton.small(
          backgroundColor: context.appThemeTokens.composerSurface,
          foregroundColor: context.appThemeTokens.foreground,
          onPressed: visible ? onTap : null,
          child: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }
}

class CodePanel extends StatelessWidget {
  const CodePanel({
    super.key,
    required this.codeBlock,
    this.onOpenSandbox,
  });

  final String codeBlock;
  final void Function(String code, String language)? onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final parsed = parseCodeBlock(codeBlock);
    final language = parsed.language;
    final code = parsed.code;
    final highlightTheme = buildCodeHighlightTheme(
      tokens: tokens,
      brightness: Theme.of(context).brightness,
    );
    final spans = highlightCode(
      code,
      language,
      theme: highlightTheme,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                Text(
                  language,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: tokens.mutedForeground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: code)),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: tokens.subtleForeground,
                    ),
                  ),
                ),
                if (onOpenSandbox != null)
                  InkWell(
                    onTap: () => onOpenSandbox!(code, language),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: tokens.subtleForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.mutedBorder),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: tokens.panelSurface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(14),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    height: 1.65,
                    color: highlightTheme['root']?.color ?? tokens.foreground,
                  ),
                  children: spans,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

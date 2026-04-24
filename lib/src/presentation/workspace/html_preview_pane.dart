import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

class HtmlPreviewPane extends StatefulWidget {
  const HtmlPreviewPane({
    super.key,
    required this.html,
    required this.onOpenExternally,
  });

  final String html;
  final Future<void> Function() onOpenExternally;

  @override
  State<HtmlPreviewPane> createState() => _HtmlPreviewPaneState();
}

class _HtmlPreviewPaneState extends State<HtmlPreviewPane> {
  static const _loadTimeout = Duration(seconds: 3);

  late final WebViewController _webViewController;
  late HtmlPreviewModel _preview;
  Timer? _fallbackTimer;
  bool _pageLoaded = false;
  bool _showFallback = false;
  bool _loading = true;
  String? _webError;

  @override
  void initState() {
    super.initState();
    _preview = buildHtmlPreviewModel(widget.html);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _fallbackTimer?.cancel();
            if (!mounted) return;
            setState(() {
              _loading = true;
              _pageLoaded = false;
              _showFallback = false;
              _webError = null;
            });
            _armFallbackTimer();
          },
          onPageFinished: (_) async {
            _fallbackTimer?.cancel();
            final shouldFallback = await _looksBlankAfterLoad();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _pageLoaded = !shouldFallback;
              _showFallback = shouldFallback;
            });
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.navigate;
            }
            if (uri.scheme == 'about' || uri.scheme == 'data') {
              return NavigationDecision.navigate;
            }
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            _fallbackTimer?.cancel();
            if (!mounted) return;
            setState(() {
              _loading = false;
              _pageLoaded = false;
              _showFallback = true;
              _webError = error.description;
            });
          },
        ),
      );
    unawaited(_loadPreview());
  }

  @override
  void didUpdateWidget(covariant HtmlPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html == widget.html) return;
    _preview = buildHtmlPreviewModel(widget.html);
    unawaited(_loadPreview());
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    _fallbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _pageLoaded = false;
        _showFallback = false;
        _webError = null;
      });
    }
    _armFallbackTimer();
    try {
      await _webViewController.loadHtmlString(
        prepareHtmlPreviewDocument(widget.html),
      );
    } catch (error) {
      _fallbackTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageLoaded = false;
        _showFallback = true;
        _webError = error.toString();
      });
    }
  }

  void _armFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(_loadTimeout, () {
      if (!mounted || _pageLoaded) return;
      setState(() {
        _loading = false;
        _showFallback = true;
      });
    });
  }

  Future<bool> _looksBlankAfterLoad() async {
    try {
      final raw = await _webViewController.runJavaScriptReturningResult('''
(() => {
  const body = document.body;
  if (!body) return JSON.stringify({ textLength: 0, htmlLength: 0, height: 0 });
  const text = (body.innerText || '').trim();
  const html = (body.innerHTML || '').trim();
  const style = window.getComputedStyle(body);
  const hidden = style.display === 'none' || style.visibility === 'hidden';
  const height = Math.max(
    body.scrollHeight || 0,
    body.offsetHeight || 0,
    document.documentElement ? document.documentElement.scrollHeight || 0 : 0,
  );
  return JSON.stringify({
    textLength: text.length,
    htmlLength: html.length,
    height,
    hidden
  });
})()
''');
      final normalized = raw.toString();
      final firstPass = jsonDecode(normalized);
      final decoded =
          firstPass is String ? jsonDecode(firstPass) : firstPass;
      if (decoded is! Map) return false;
      final textLength = decoded['textLength'] as num? ?? 0;
      final htmlLength = decoded['htmlLength'] as num? ?? 0;
      final height = decoded['height'] as num? ?? 0;
      final hidden = decoded['hidden'] == true;
      return hidden || (textLength <= 0 && htmlLength <= 0) || height <= 4;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;

    return ColoredBox(
      color: tokens.appBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.panelSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.mutedBorder),
              boxShadow: [
                BoxShadow(
                  color: tokens.shadow.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _showFallback
                  ? _HtmlFallbackView(
                      preview: _preview,
                      webError: _webError,
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: Colors.white),
                        WebViewWidget(controller: _webViewController),
                        if (_loading)
                          ColoredBox(
                            color: tokens.panelSurface,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.elevatedSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: tokens.mutedBorder,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.6,
                                        color: tokens.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Loading HTML preview...',
                                      style: TextStyle(
                                        color: tokens.foreground,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HtmlFallbackView extends StatelessWidget {
  const _HtmlFallbackView({
    required this.preview,
    required this.webError,
  });

  final HtmlPreviewModel preview;
  final String? webError;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview.title != null && preview.title!.trim().isNotEmpty) ...[
            Text(
              preview.title!,
              style: TextStyle(
                color: tokens.foreground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                tokens.accent.withValues(alpha: 0.08),
                tokens.elevatedSurface,
              ),
              border: Border.all(color: tokens.mutedBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              webError == null || webError!.trim().isEmpty
                  ? 'Showing a safe in-app fallback preview because the original page did not render reliably here.'
                  : 'Showing a safe in-app fallback preview because the original page did not render reliably here: $webError',
              style: TextStyle(
                color: tokens.mutedForeground,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (preview.hasRenderableContent)
            HtmlWidget(
              preview.renderHtml,
              renderMode: RenderMode.column,
              textStyle: TextStyle(
                color: tokens.foreground,
                fontSize: 15,
                height: 1.55,
              ),
              onTapUrl: (url) async {
                final uri = Uri.tryParse(url);
                if (uri == null) return false;
                return launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
              },
            )
          else
            _EmptyPreviewState(
              title: preview.title,
              message: preview.emptyMessage,
            ),
        ],
      ),
    );
  }
}

class _EmptyPreviewState extends StatelessWidget {
  const _EmptyPreviewState({
    required this.title,
    required this.message,
  });

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title!.trim().isNotEmpty) ...[
          Text(
            title!,
            style: TextStyle(
              color: tokens.foreground,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          message,
          style: TextStyle(
            color: tokens.mutedForeground,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class HtmlPreviewModel {
  const HtmlPreviewModel({
    required this.renderHtml,
    required this.hasRenderableContent,
    required this.removedInteractiveContent,
    required this.emptyMessage,
    this.title,
  });

  final String renderHtml;
  final bool hasRenderableContent;
  final bool removedInteractiveContent;
  final String emptyMessage;
  final String? title;
}

String prepareHtmlPreviewDocument(String html) {
  final hasHtmlShell =
      RegExp(r'<html[\s>]', caseSensitive: false).hasMatch(html) ||
          RegExp(r'<!doctype html', caseSensitive: false).hasMatch(html);
  if (hasHtmlShell) {
    return html;
  }

  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
  </head>
  <body>
    $html
  </body>
</html>
''';
}

HtmlPreviewModel buildHtmlPreviewModel(String sourceHtml) {
  final document = html_parser.parse(sourceHtml);
  final title = document.querySelector('title')?.text.trim();
  final root = (document.body ?? document.documentElement)?.clone(true);

  if (root == null) {
    return const HtmlPreviewModel(
      renderHtml: '',
      hasRenderableContent: false,
      removedInteractiveContent: false,
      emptyMessage:
          'This file does not contain previewable HTML content inside the app.',
    );
  }

  for (final node in root.querySelectorAll('script,noscript,template')) {
    node.remove();
  }

  var removedInteractiveContent = false;
  for (final node in root.querySelectorAll('iframe,canvas,video,audio,form')) {
    removedInteractiveContent = true;
    node.replaceWith(
      dom.Element.tag('div')
        ..attributes['style'] =
            'padding:12px 14px;border:1px solid #d0d7de;border-radius:12px;background:#f6f8fa;margin:10px 0;'
        ..text = 'This interactive section is available in browser view.',
    );
  }

  final hasVisualElements = root.querySelector(
        'img,svg,table,ul,ol,pre,blockquote,section,article,main,header,footer,div,p,h1,h2,h3,h4,h5,h6',
      ) !=
      null;
  final hasText = root.text.trim().isNotEmpty;
  final hasRenderableContent = hasVisualElements || hasText;

  final inlineStyles = document
      .querySelectorAll('style')
      .map((style) => style.outerHtml)
      .join('\n');

  final renderHtml = '''
$inlineStyles
<div class="gidar-html-preview">
  ${root.innerHtml.trim()}
</div>
'''
      .trim();

  final emptyMessage = removedInteractiveContent
      ? 'This HTML mostly depends on browser-only interactive code, so the app can only show a simplified preview. Use the browser button below for the original page.'
      : 'This HTML did not produce visible static content inside the app preview.';

  return HtmlPreviewModel(
    title: title,
    renderHtml: renderHtml,
    hasRenderableContent: hasRenderableContent,
    removedInteractiveContent: removedInteractiveContent,
    emptyMessage: emptyMessage,
  );
}

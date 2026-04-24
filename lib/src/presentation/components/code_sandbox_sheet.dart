import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

class CodeSandboxSheet extends StatefulWidget {
  const CodeSandboxSheet({
    super.key,
    required this.initialCode,
    required this.language,
  });

  final String initialCode;
  final String language;

  @override
  State<CodeSandboxSheet> createState() => _CodeSandboxSheetState();
}

class _CodeSandboxSheetState extends State<CodeSandboxSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _codeController;
  late final TabController _tabController;
  late final WebViewController _webViewController;
  final List<_ConsoleLine> _consoleLines = [];
  bool _appliedThemeBackground = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);
    _tabController = TabController(length: 3, vsync: this);
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'GidarConsole',
        onMessageReceived: (message) {
          final raw = message.message;
          final separator = raw.indexOf('|');
          if (!mounted) return;
          setState(() {
            if (separator == -1) {
              _consoleLines.add(_ConsoleLine('log', raw));
            } else {
              _consoleLines.add(
                _ConsoleLine(
                  raw.substring(0, separator),
                  raw.substring(separator + 1),
                ),
              );
            }
          });
        },
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _runCode();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedThemeBackground) return;
    _appliedThemeBackground = true;
    _webViewController.setBackgroundColor(context.appThemeTokens.panelSurface);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runCode() async {
    final code = _codeController.text;
    final tokens = context.appThemeTokens;
    setState(_consoleLines.clear);
    _tabController.animateTo(1);

    if (_looksLikeHtml(code, widget.language)) {
      await _webViewController.loadHtmlString(code);
      return;
    }

    final sandboxHtml = '''
<!DOCTYPE html>
<html>
  <body style="background:${_cssColor(tokens.panelSurface)};color:${_cssColor(tokens.foreground)};font-family:sans-serif;">
    <div id="app"></div>
    <script>
      const send = (type, value) => GidarConsole.postMessage(type + "|" + value);
      console.log = (...args) => send("log", args.join(" "));
      console.warn = (...args) => send("warn", args.join(" "));
      console.error = (...args) => send("error", args.join(" "));
      try {
        $code
      } catch (error) {
        send("error", error.toString());
      }
    </script>
  </body>
</html>
''';
    await _webViewController.loadHtmlString(sandboxHtml);
  }

  bool _looksLikeHtml(String code, String language) {
    final trimmed = code.trimLeft();
    return language.toLowerCase() == 'html' || trimmed.startsWith('<');
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return SafeArea(
      child: ColoredBox(
        color: tokens.modalSurface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  Text(
                    'Code Sandbox',
                    style: TextStyle(
                      color: tokens.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _runCode,
                    child: const Text('Run'),
                  ),
                  TextButton(
                    onPressed: () {
                      _codeController.clear();
                      setState(_consoleLines.clear);
                    },
                    child: const Text('Clear'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: tokens.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Code'),
                Tab(text: 'Output'),
                Tab(text: 'Console'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _codeController,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      style: TextStyle(
                        color: tokens.foreground,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: tokens.elevatedSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: WebViewWidget(controller: _webViewController),
                    ),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _consoleLines.length,
                    itemBuilder: (context, index) {
                      final line = _consoleLines[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          line.message,
                          style: TextStyle(
                            color: switch (line.type) {
                              'warn' => const Color(0xFFD97706),
                              'error' => const Color(0xFFDC2626),
                              _ => const Color(0xFF2E9E72),
                            },
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
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

class _ConsoleLine {
  const _ConsoleLine(this.type, this.message);

  final String type;
  final String message;
}

String _cssColor(Color color) {
  return 'rgba(${(color.r * 255).round()}, ${(color.g * 255).round()}, ${(color.b * 255).round()}, ${color.a.toStringAsFixed(3)})';
}

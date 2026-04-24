import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/file_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../components/code_utils.dart';
import 'html_preview_pane.dart';

class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.fileName,
    required this.language,
    required this.code,
  });

  final String fileName;
  final String language;
  final String code;

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool get _isHtml => widget.language.toLowerCase() == 'html';
  bool get _isSvg => widget.language.toLowerCase() == 'svg';
  bool get _hasPreview => _isHtml || _isSvg;
  String get _exportFileName {
    return ensureExportFileName(
      widget.fileName.contains('.')
          ? widget.fileName
          : '${widget.fileName}${fileExtension(widget.language)}',
      language: widget.language,
    );
  }

  String get _exportMimeType => inferMimeType(
        _exportFileName,
        language: widget.language,
      );

  Future<void> _openHtmlExternally() async {
    final html = prepareHtmlPreviewDocument(widget.code);
    final uri = Uri.dataFromString(
      html,
      mimeType: 'text/html',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not open preview externally'),
        backgroundColor: context.appThemeTokens.modalSurface,
      ),
    );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Code copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: context.appThemeTokens.modalSurface,
      ),
    );
  }

  Future<void> _shareCode() async {
    try {
      await shareTextFile(
        fileName: _exportFileName,
        content: widget.code,
        mimeType: _exportMimeType,
        language: widget.language,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Share failed: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.appThemeTokens.modalSurface,
        ),
      );
    }
  }

  Future<void> _downloadCode() async {
    try {
      final savedPath = await saveTextFileToDownloads(
        fileName: _exportFileName,
        content: widget.code,
        mimeType: _exportMimeType,
        language: widget.language,
      );
      if (!mounted) return;
      final savedMessage = savedPath.startsWith('content://')
          ? 'Saved to Downloads'
          : 'Saved to $savedPath';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedMessage),
          duration: const Duration(seconds: 2),
          backgroundColor: context.appThemeTokens.modalSurface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.appThemeTokens.modalSurface,
        ),
      );
    }
  }

  Future<void> _printHtml() async {
    try {
      await Printing.layoutPdf(
        name: widget.fileName,
        onLayout: (format) async {
          // ignore: deprecated_member_use
          return await Printing.convertHtml(
            html: widget.code,
            format: format,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.appThemeTokens.modalSurface,
        ),
      );
    }
  }

  void _showCodeSheet() {
    final tokens = context.appThemeTokens;
    final highlightTheme = buildCodeHighlightTheme(
      tokens: tokens,
      brightness: Theme.of(context).brightness,
    );
    final spans = highlightCode(
      widget.code,
      widget.language,
      theme: highlightTheme,
    );
    final lineCount = '\n'.allMatches(widget.code).length + 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.modalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: tokens.mutedBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$lineCount lines',
                        style: TextStyle(
                          color: tokens.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: _copyCode,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.copy_rounded,
                              size: 18, color: tokens.subtleForeground),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.close_rounded,
                              size: 18, color: tokens.subtleForeground),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText.rich(
                        TextSpan(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            height: 1.7,
                            color: highlightTheme['root']?.color ??
                                tokens.foreground,
                          ),
                          children: spans,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'preview':
        // Already showing preview
        break;
      case 'code':
        _showCodeSheet();
        break;
      case 'copy':
        _copyCode();
        break;
      case 'share':
        _shareCode();
        break;
      case 'download':
        _downloadCode();
        break;
      case 'print':
        _printHtml();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Scaffold(
      backgroundColor: tokens.appBackground,
      appBar: AppBar(
        backgroundColor: tokens.topBarSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: tokens.mutedForeground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: fileIconColor(widget.language).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileIcon(widget.language),
                size: 18,
                color: fileIconColor(widget.language),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName,
                    style: TextStyle(
                      color: tokens.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.language.toUpperCase(),
                    style: TextStyle(
                      color: tokens.mutedForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: tokens.mutedForeground,
              size: 22,
            ),
            onSelected: _handleMenuAction,
            color: tokens.modalSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              if (_hasPreview)
                _menuTile(Icons.visibility_rounded, 'Preview', 'preview'),
              _menuTile(Icons.code_rounded, 'Code', 'code'),
              _menuTile(Icons.copy_rounded, 'Copy', 'copy'),
              _menuTile(Icons.share_rounded, 'Share', 'share'),
              _menuTile(Icons.download_rounded, 'Download', 'download'),
              if (_isHtml) _menuTile(Icons.print_rounded, 'Print', 'print'),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isHtml
          ? HtmlPreviewPane(
              html: prepareHtmlPreviewDocument(widget.code),
              onOpenExternally: _openHtmlExternally,
            )
          : _isSvg
              ? _buildSvgPreview()
          : _buildCodeView(),
    );
  }

  PopupMenuItem<String> _menuTile(IconData icon, String label, String value) {
    final tokens = context.appThemeTokens;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.mutedForeground),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: tokens.foreground, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeView() {
    final tokens = context.appThemeTokens;
    final highlightTheme = buildCodeHighlightTheme(
      tokens: tokens,
      brightness: Theme.of(context).brightness,
    );
    final spans = highlightCode(
      widget.code,
      widget.language,
      theme: highlightTheme,
    );
    final lineCount = '\n'.allMatches(widget.code).length + 1;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: tokens.topBarSurface,
            border: Border(
              bottom: BorderSide(
                color: tokens.mutedBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '$lineCount lines',
                style: TextStyle(
                  color: tokens.mutedForeground,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _copyCode,
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
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    height: 1.7,
                    color: highlightTheme['root']?.color ?? tokens.foreground,
                  ),
                  children: spans,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSvgPreview() {
    final tokens = context.appThemeTokens;
    return Padding(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 6,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    minHeight: constraints.maxHeight,
                  ),
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: SvgPicture.string(
                    widget.code,
                    fit: BoxFit.contain,
                    placeholderBuilder: (context) => SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: tokens.accent,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

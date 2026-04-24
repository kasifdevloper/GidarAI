import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../workspace/html_preview_pane.dart';

class HtmlPreviewSheet extends StatelessWidget {
  const HtmlPreviewSheet({
    super.key,
    required this.html,
    this.title = 'HTML Preview',
  });

  final String html;
  final String title;

  Future<void> _openExternally(BuildContext context) async {
    final uri = Uri.dataFromString(html, mimeType: 'text/html');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Could not open preview externally'),
        backgroundColor: context.appThemeTokens.modalSurface,
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.foreground,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
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
            Divider(height: 1, color: tokens.mutedBorder),
            Expanded(
              child: HtmlPreviewPane(
                html: html,
                onOpenExternally: () => _openExternally(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

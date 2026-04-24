import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';

import '../../core/models/app_models.dart';
import '../../core/services/file_export_service.dart';
import '../../core/theme/app_theme.dart';
import '../components/app_ui.dart';
import '../components/code_utils.dart';
import '../components/html_preview_sheet.dart';
import '../components/message_item.dart';
import '../sidebar/sidebar_drawer.dart';
import 'file_viewer_screen.dart';
import 'html_preview_pane.dart';

const _pdfFontRegularAsset = 'assets/fonts/pdf/GoNotoCurrent-Regular.ttf';
const _pdfFontBoldAsset = 'assets/fonts/pdf/GoNotoCurrent-Bold.ttf';
const _pdfEmojiFontAsset = 'assets/fonts/pdf/Noto-COLRv1-emojicompat.ttf';
const _pdfSoftWrapWidth = 72;
const _pdfBodyChunkLength = 600;
const _pdfCodeChunkLength = 1400;
const _pdfMaxMessageCharacters = 12000;
const _pdfMaxCodeCharacters = 5000;
const _pdfMaxHtmlPreviewCharacters = 2600;
Future<pw.ThemeData>? _cachedPdfTheme;

Future<T?> showWorkspaceBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: context.appThemeTokens.modalSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}

void showWorkspaceHtmlPreviewSheet(BuildContext context, String html) {
  showWorkspaceBottomSheet<void>(
    context,
    isScrollControlled: true,
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: HtmlPreviewSheet(html: html),
    ),
  );
}

void showWorkspaceCodeSandboxSheet(
  BuildContext context,
  String code,
  String language,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FileViewerScreen(
        fileName: 'code.$language',
        language: language,
        code: code,
      ),
    ),
  );
}

Future<File> saveWorkspaceHtmlPreview(String html) async {
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${directory.path}\\gidar_preview_$timestamp.html');
  await file.writeAsString(html);
  return file;
}

Future<void> shareChatSessionPdf({
  required BuildContext context,
  required ChatSession session,
  required String modelName,
}) async {
  final bytes = await _runChatPdfProgressFlow<Uint8List>(
    context: context,
    mode: _ChatPdfFlowMode.share,
    task: (update) async {
      update(
        const _ChatPdfProgressState.progress(
          progress: 0.12,
          title: 'Converting to PDF',
          message: 'Preparing chat layout...',
        ),
      );
      final bytes = await _buildBestChatSessionPdfBytes(
        context: context,
        session: session,
        modelName: modelName,
        onProgress: update,
      );
      update(
        const _ChatPdfProgressState.progress(
          progress: 0.92,
          title: 'Converting to PDF',
          message: 'Getting share sheet ready...',
        ),
      );
      update(
        const _ChatPdfProgressState.completed(
          title: 'PDF ready',
          message: 'Opening share options...',
        ),
      );
      return bytes;
    },
  );
  await Printing.sharePdf(
    bytes: bytes,
    filename: '${session.title.replaceAll(' ', '_')}.pdf',
  );
}

Future<String> saveChatSessionPdfLocally({
  required BuildContext context,
  required ChatSession session,
  required String modelName,
}) {
  return _runChatPdfProgressFlow<String>(
    context: context,
    mode: _ChatPdfFlowMode.export,
    task: (update) async {
      update(
        const _ChatPdfProgressState.progress(
          progress: 0.12,
          title: 'Converting to PDF',
          message: 'Preparing chat layout...',
        ),
      );
      final bytes = await _buildBestChatSessionPdfBytes(
        context: context,
        session: session,
        modelName: modelName,
        onProgress: update,
      );
      update(
        const _ChatPdfProgressState.progress(
          progress: 0.92,
          title: 'Converting to PDF',
          message: 'Saving to local storage...',
        ),
      );
      final filePath = await _savePdfBytesToLocalFile(
        session: session,
        bytes: bytes,
      );
      update(
        const _ChatPdfProgressState.completed(
          title: 'Download complete',
          message: 'PDF saved to Downloads.',
        ),
      );
      return filePath;
    },
  );
}

Future<Uint8List> _buildChatSessionScreenshotPdfBytes({
  required BuildContext context,
  required ChatSession session,
  required String modelName,
  ValueChanged<_ChatPdfProgressState>? onProgress,
}) async {
  final mediaQuery = MediaQuery.of(context);
  final captureWidth = mediaQuery.size.width.clamp(360.0, 480.0);
  final pixelRatio = mediaQuery.devicePixelRatio.clamp(2.0, 3.0);
  final segments = _buildChatExportSegments(session.messages);

  onProgress?.call(
    const _ChatPdfProgressState.progress(
      progress: 0.18,
      title: 'Converting to PDF',
      message: 'Preparing chat snapshots...',
    ),
  );
  final pdfWidth = captureWidth * 0.96;
  final document = pw.Document(compress: true);
  for (var index = 0; index < segments.length; index++) {
    final progressStart = 0.22 + (0.52 * (index / segments.length));
    onProgress?.call(
      _ChatPdfProgressState.progress(
        progress: progressStart.clamp(0.22, 0.78),
        title: 'Converting to PDF',
        message: segments.length == 1
            ? 'Capturing the chat screen...'
            : 'Capturing section ${index + 1} of ${segments.length}...',
      ),
    );
    if (!context.mounted) {
      throw StateError('Chat export context was disposed.');
    }
    final imageBytes = await _captureChatExportSegment(
      context: context,
      mediaQuery: mediaQuery,
      captureWidth: captureWidth,
      pixelRatio: pixelRatio,
      session: session,
      modelName: modelName,
      messages: segments[index],
      sectionIndex: index,
      sectionCount: segments.length,
    );
    final imageSize = await _decodeImageSize(imageBytes);
    final pdfHeight = pdfWidth * (imageSize.height / imageSize.width);
    final provider = pw.MemoryImage(imageBytes);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pdfWidth, pdfHeight),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox.expand(
          child: pw.Image(
            provider,
            fit: pw.BoxFit.fill,
          ),
        ),
      ),
    );
  }

  onProgress?.call(
    const _ChatPdfProgressState.progress(
      progress: 0.86,
      title: 'Converting to PDF',
      message: 'Finalizing PDF document...',
    ),
  );

  return document.save();
}

Future<Uint8List> _captureChatExportSegment({
  required BuildContext context,
  required MediaQueryData mediaQuery,
  required double captureWidth,
  required double pixelRatio,
  required ChatSession session,
  required String modelName,
  required List<ChatMessage> messages,
  required int sectionIndex,
  required int sectionCount,
}) async {
  final screenshotController = ScreenshotController();
  final captureWidget = InheritedTheme.captureAll(
    context,
    MediaQuery(
      data: mediaQuery.copyWith(
        size: Size(captureWidth, mediaQuery.size.height),
        viewInsets: EdgeInsets.zero,
        padding: EdgeInsets.zero,
      ),
      child: Directionality(
        textDirection: Directionality.of(context),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: SizedBox(
              width: captureWidth,
              child: _ChatExportCaptureSurface(
                session: session,
                modelName: modelName,
                messages: messages,
                sectionIndex: sectionIndex,
                sectionCount: sectionCount,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  return screenshotController.captureFromLongWidget(
    captureWidget,
    context: context,
    delay: const Duration(milliseconds: 40),
    pixelRatio: pixelRatio,
    constraints: BoxConstraints(
      minWidth: captureWidth,
      maxWidth: captureWidth,
    ),
  );
}

List<List<ChatMessage>> _buildChatExportSegments(List<ChatMessage> messages) {
  if (messages.isEmpty) {
    return const [<ChatMessage>[]];
  }

  const maxSegmentWeight = 9000;
  const maxMessagesPerSegment = 10;
  final segments = <List<ChatMessage>>[];
  var current = <ChatMessage>[];
  var currentWeight = 0;

  for (final message in messages) {
    final attachmentWeight = message.attachments.length * 1600;
    final messageWeight = math.max(
      1,
      message.content.length + (message.requestText?.length ?? 0) + attachmentWeight,
    );
    final shouldSplit = current.isNotEmpty &&
        (current.length >= maxMessagesPerSegment ||
            currentWeight + messageWeight > maxSegmentWeight);
    if (shouldSplit) {
      segments.add(List<ChatMessage>.unmodifiable(current));
      current = <ChatMessage>[];
      currentWeight = 0;
    }
    current.add(message);
    currentWeight += messageWeight;
  }

  if (current.isNotEmpty) {
    segments.add(List<ChatMessage>.unmodifiable(current));
  }

  return segments;
}

Future<Uint8List> _buildBestChatSessionPdfBytes({
  required BuildContext context,
  required ChatSession session,
  required String modelName,
  required ValueChanged<_ChatPdfProgressState> onProgress,
}) async {
  try {
    onProgress(
      const _ChatPdfProgressState.progress(
        progress: 0.34,
        title: 'Converting to PDF',
        message: 'Rendering chat screen...',
      ),
    );
    final bytes = await _buildChatSessionScreenshotPdfBytes(
      context: context,
      session: session,
      modelName: modelName,
      onProgress: onProgress,
    );
    onProgress(
      const _ChatPdfProgressState.progress(
        progress: 0.9,
        title: 'Converting to PDF',
        message: 'Finishing screenshot PDF...',
      ),
    );
    return bytes;
  } catch (_) {
    onProgress(
      const _ChatPdfProgressState.progress(
        progress: 0.46,
        title: 'Converting to PDF',
        message: 'Using compatibility export mode...',
      ),
    );
    final bytes = await buildChatSessionPdfBytes(
      session: session,
      modelName: modelName,
    );
    onProgress(
      const _ChatPdfProgressState.progress(
        progress: 0.86,
        title: 'Converting to PDF',
        message: 'Finalizing PDF document...',
      ),
    );
    return bytes;
  }
}

Future<String> _savePdfBytesToLocalFile({
  required ChatSession session,
  required Uint8List bytes,
}) async {
  final sanitizedTitle = _sanitizePdfFileName(
    session.title.trim().isEmpty ? 'gidar_chat' : session.title,
  );
  final fileName = '${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  return saveBinaryFileToDownloads(
    fileName: fileName,
    bytes: bytes,
    mimeType: 'application/pdf',
  );
}

String _sanitizePdfFileName(String input) {
  return input
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '')
      .toLowerCase();
}

enum _ChatPdfFlowMode { export, share }

class _ChatPdfProgressState {
  const _ChatPdfProgressState({
    required this.progress,
    required this.title,
    required this.message,
    required this.completed,
    required this.failed,
  });

  const _ChatPdfProgressState.progress({
    required this.progress,
    required this.title,
    required this.message,
  })  : completed = false,
        failed = false;

  const _ChatPdfProgressState.completed({
    required this.title,
    required this.message,
  })  : progress = 1,
        completed = true,
        failed = false;

  const _ChatPdfProgressState.failed({
    required this.title,
    required this.message,
  })  : progress = 1,
        completed = false,
        failed = true;

  final double progress;
  final String title;
  final String message;
  final bool completed;
  final bool failed;

  _ChatPdfProgressState copyWith({
    double? progress,
    String? title,
    String? message,
    bool? completed,
    bool? failed,
  }) {
    return _ChatPdfProgressState(
      progress: progress ?? this.progress,
      title: title ?? this.title,
      message: message ?? this.message,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
    );
  }
}

Future<T> _runChatPdfProgressFlow<T>({
  required BuildContext context,
  required _ChatPdfFlowMode mode,
  required Future<T> Function(ValueChanged<_ChatPdfProgressState> update) task,
}) async {
  const initialState = _ChatPdfProgressState.progress(
    progress: 0.04,
    title: 'Converting to PDF',
    message: 'Starting export...',
  );
  final state = ValueNotifier<_ChatPdfProgressState>(initialState);
  var lastReportedState = initialState;
  final flowStartedAt = DateTime.now();
  final progressSmoother = Timer.periodic(const Duration(milliseconds: 110), (
    _,
  ) {
    if (lastReportedState.completed || lastReportedState.failed) {
      return;
    }
    final elapsedMs = DateTime.now().difference(flowStartedAt).inMilliseconds;
    final autoProgress = 0.08 +
        0.8 *
            Curves.easeOutCubic.transform(
              (elapsedMs / 5200).clamp(0.0, 1.0),
            );
    final nextProgress = math.max(
      lastReportedState.progress,
      math.min(autoProgress, 0.9),
    );
    if ((nextProgress - state.value.progress).abs() < 0.012) {
      return;
    }
    state.value = lastReportedState.copyWith(progress: nextProgress);
  });

  void setState(_ChatPdfProgressState next) {
    lastReportedState = next;
    state.value = next;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => _ChatPdfProgressScreen(
        stateListenable: state,
        mode: mode,
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.96,
                end: 1,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    ),
  );

  await SchedulerBinding.instance.endOfFrame;
  await SchedulerBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 110));
  try {
    final result = await task(setState);
    setState(
      lastReportedState.copyWith(
        progress: 1,
        completed: true,
        failed: false,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 620));
    if (navigator.canPop()) {
      navigator.pop();
    }
    return result;
  } catch (error) {
    setState(
      const _ChatPdfProgressState.failed(
        title: 'PDF failed',
        message: 'Something went wrong while creating the PDF.',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 980));
    if (navigator.canPop()) {
      navigator.pop();
    }
    rethrow;
  } finally {
    progressSmoother.cancel();
    state.dispose();
  }
}

Future<Size> _decodeImageSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return Size(
    frame.image.width.toDouble(),
    frame.image.height.toDouble(),
  );
}

class _ChatExportCaptureSurface extends StatelessWidget {
  const _ChatExportCaptureSurface({
    required this.session,
    required this.modelName,
    required this.messages,
    required this.sectionIndex,
    required this.sectionCount,
  });

  final ChatSession session;
  final String modelName;
  final List<ChatMessage> messages;
  final int sectionIndex;
  final int sectionCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    final brightness = Theme.of(context).brightness;
    final isFirstSection = sectionIndex == 0;
    final isLastSection = sectionIndex == sectionCount - 1;
    final background = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: brightness == Brightness.dark
          ? [
              tokens.appBackground,
              Color.alphaBlend(
                tokens.panelSurface.withValues(alpha: 0.18),
                tokens.appBackground,
              ),
            ]
          : [
              tokens.appBackground,
              Color.alphaBlend(
                tokens.accent.withValues(alpha: 0.05),
                tokens.appBackground,
              ),
            ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: background),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          isFirstSection ? 18 : 8,
          16,
          isLastSection ? 28 : 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isFirstSection) ...[
              GidarTopBar(
                title: modelName,
                leadingIcon: Icons.chat_bubble_outline_rounded,
                onLeadingTap: () {},
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${session.updatedAt.hour.toString().padLeft(2, '0')}:${session.updatedAt.minute.toString().padLeft(2, '0')}',
                    style: typography.chatMeta.copyWith(
                      color: tokens.subtleForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: tokens.panelSurface.withValues(
                    alpha: brightness == Brightness.dark ? 0.82 : 0.9,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: tokens.mutedBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: typography.chatStrong.copyWith(
                        color: tokens.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sectionCount > 1
                          ? 'Scrollable chat export snapshot'
                          : 'Scrollable chat export snapshot',
                      style: typography.chatMeta.copyWith(
                        color: tokens.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ] else ...[
              Container(
                height: 22,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      tokens.mutedBorder.withValues(alpha: 0.08),
                      tokens.mutedBorder.withValues(alpha: 0.02),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 52,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: tokens.mutedForeground.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ],
            for (final message in messages)
              if (message.role == 'user')
                UserMessageBubble(message: message)
              else if (message.role == 'assistant')
                AssistantMessageCard(
                  message: message,
                  onOpenSandbox: (_, __) {},
                )
              else
                const SizedBox.shrink(),
            if (!isLastSection)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.mutedBorder.withValues(alpha: 0.02),
                        tokens.mutedBorder.withValues(alpha: 0.08),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatPdfProgressScreen extends StatelessWidget {
  const _ChatPdfProgressScreen({
    required this.stateListenable,
    required this.mode,
  });

  final ValueListenable<_ChatPdfProgressState> stateListenable;
  final _ChatPdfFlowMode mode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 298),
            child: ValueListenableBuilder<_ChatPdfProgressState>(
              valueListenable: stateListenable,
              builder: (context, state, _) {
                final actionLabel = switch (mode) {
                  _ChatPdfFlowMode.export => 'Exporting chat',
                  _ChatPdfFlowMode.share => 'Preparing share',
                };
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
                  decoration: BoxDecoration(
                    color: tokens.panelSurface.withValues(
                      alpha: isDark ? 0.97 : 0.985,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: tokens.mutedBorder.withValues(
                        alpha: isDark ? 0.95 : 0.88,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tokens.shadow.withValues(
                          alpha: isDark ? 0.24 : 0.1,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _ChatPdfProgressHero(state: state),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  actionLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.chatMeta.copyWith(
                                    color: tokens.mutedForeground,
                                    letterSpacing: 0.25,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  state.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.chatStrong.copyWith(
                                    color: tokens.foreground,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.chatMeta.copyWith(
                                    color: tokens.subtleForeground,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _ChatPdfProgressBar(
                        progress: state.failed ? 1 : state.progress,
                        color: state.completed
                            ? const Color(0xFF16A34A)
                            : state.failed
                                ? const Color(0xFFDC2626)
                                : tokens.accent,
                        trackColor: tokens.subtleSurface,
                        active: !state.completed && !state.failed,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatPdfProgressBar extends StatefulWidget {
  const _ChatPdfProgressBar({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.active,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final bool active;

  @override
  State<_ChatPdfProgressBar> createState() => _ChatPdfProgressBarState();
}

class _ChatPdfProgressBarState extends State<_ChatPdfProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheenController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1180),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _sheenController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _ChatPdfProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_sheenController.isAnimating) {
      _sheenController.repeat();
    } else if (!widget.active && _sheenController.isAnimating) {
      _sheenController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final sheenWidth = width * 0.18;
            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: widget.trackColor),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: widget.progress.clamp(0, 1),
                  ),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * value,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              widget.color.withValues(alpha: 0.86),
                              widget.color,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (widget.active)
                  AnimatedBuilder(
                    animation: _sheenController,
                    builder: (context, _) {
                      final left =
                          (width + sheenWidth) * _sheenController.value -
                              sheenWidth;
                      return Positioned(
                        left: left,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: sheenWidth,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChatPdfProgressHero extends StatelessWidget {
  const _ChatPdfProgressHero({required this.state});

  final _ChatPdfProgressState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final heroColor = state.completed
        ? const Color(0xFF16A34A)
        : state.failed
            ? const Color(0xFFDC2626)
            : tokens.accent;
    final heroIcon = state.completed
        ? Icons.check_rounded
        : state.failed
            ? Icons.close_rounded
            : Icons.picture_as_pdf_rounded;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: state.completed ? 1.04 : 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: heroColor.withValues(alpha: 0.12),
          border: Border.all(
            color: heroColor.withValues(alpha: 0.22),
          ),
        ),
        child: Center(
          child: Icon(
            heroIcon,
            size: state.completed ? 22 : 20,
            color: heroColor,
          ),
        ),
      ),
    );
  }
}

Future<Uint8List> buildChatSessionPdfBytes({
  required ChatSession session,
  required String modelName,
}) async {
  final theme = await _loadWorkspacePdfTheme();
  final document = pw.Document(compress: true);
  document.addPage(
    pw.MultiPage(
      theme: theme,
      margin: const pw.EdgeInsets.all(24),
      maxPages: 1000,
      build: (context) => [
        pw.Text(
          session.title,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Model: $modelName'),
        pw.Text('Updated: ${session.updatedAt.toLocal()}'),
        pw.SizedBox(height: 18),
        ...session.messages.expand(_buildPdfMessageWidgets),
      ],
    ),
  );

  return document.save();
}

List<pw.Widget> _buildPdfMessageWidgets(ChatMessage message) {
  final isUser = message.role == 'user';
  final backgroundColor =
      isUser ? PdfColor.fromHex('#E8EEF9') : PdfColor.fromHex('#F3F3F4');
  final contentWidgets = _buildPdfMessageContent(message: message);
  final headerChildren = <pw.Widget>[
    pw.Text(
      isUser ? 'You' : 'Gidar AI',
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  ];

  if (message.attachments.isNotEmpty) {
    headerChildren.addAll([
      pw.SizedBox(height: 6),
      pw.Text(
        'Attachments: ${message.attachments.map((item) => item.name).join(', ')}',
        style: const pw.TextStyle(
          fontSize: 10.5,
          color: PdfColors.blueGrey700,
        ),
      ),
    ]);
  }

  final widgets = <pw.Widget>[
    _buildPdfMessageSection(
      backgroundColor: backgroundColor,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: headerChildren,
      ),
    ),
  ];

  if (contentWidgets.isEmpty) {
    widgets.add(
      _buildPdfMessageSection(
        backgroundColor: backgroundColor,
        child: pw.Text(
          'No text content',
          style: const pw.TextStyle(
            fontSize: 11,
            color: PdfColors.blueGrey400,
          ),
        ),
        compact: true,
      ),
    );
  } else {
    widgets.addAll(
      contentWidgets.map(
        (widget) => _buildPdfMessageSection(
          backgroundColor: backgroundColor,
          child: widget,
          compact: true,
        ),
      ),
    );
  }

  widgets.add(pw.SizedBox(height: 12));
  return widgets;
}

pw.Widget _buildPdfMessageSection({
  required PdfColor backgroundColor,
  required pw.Widget child,
  bool compact = false,
}) {
  return pw.Container(
    margin: pw.EdgeInsets.only(bottom: compact ? 6 : 4),
    padding: pw.EdgeInsets.all(compact ? 10 : 12),
    decoration: pw.BoxDecoration(
      color: backgroundColor,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: child,
  );
}

List<pw.Widget> _buildPdfMessageContent({
  required ChatMessage message,
}) {
  final content = message.content.trimRight();
  if (content.isEmpty) {
    return const [];
  }

  final firstCodeBlock = extractFirstCodeBlock(content);
  final detectedFile = firstCodeBlock == null
      ? null
      : detectFileFromCodeBlock(
          firstCodeBlock.code,
          firstCodeBlock.language,
        );
  final segments = splitMarkdown(content);
  final widgets = <pw.Widget>[];
  if (detectedFile != null) {
    widgets.add(_buildPdfDetectedFileWidget(detectedFile));
  }
  var emittedCharacters = 0;
  for (final segment in segments) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (trimmed.startsWith('```')) {
      if (emittedCharacters >= _pdfMaxMessageCharacters) {
        break;
      }
      widgets.addAll(_buildPdfCodeSegmentWidgets(trimmed));
      emittedCharacters += trimmed.length;
      continue;
    }
    if (emittedCharacters >= _pdfMaxMessageCharacters) {
      break;
    }
    final remaining = _pdfMaxMessageCharacters - emittedCharacters;
    final capped = trimmed.length > remaining
        ? _truncateForPdf(trimmed, remaining)
        : trimmed;
    widgets.addAll(_buildPdfTextSegmentWidgets(capped));
    emittedCharacters += capped.length;
  }

  if (content.length > _pdfMaxMessageCharacters) {
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          '[Export condensed for PDF stability]',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.blueGrey500,
          ),
        ),
      ),
    );
  }

  return widgets.isEmpty
      ? [
          pw.Text(
            _softWrapForPdf(content),
          ),
        ]
      : widgets;
}

pw.Widget _buildPdfDetectedFileWidget(DetectedFile file) {
  final lineCount = '\n'.allMatches(file.code).length + 1;
  final accent = _pdfLanguageAccent(file.language);
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('#F8FAFC'),
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColor.fromHex('#D9E1EC')),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 30,
          height: 30,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(7),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            file.language.isEmpty
                ? '•'
                : file.language.substring(0, 1).toUpperCase(),
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                file.fileName,
                style: pw.TextStyle(
                  fontSize: 12.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1F2937'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPdfChip(
                    file.language.toUpperCase(),
                    background: PdfColor.fromHex('#E9EEF8'),
                    foreground: PdfColor.fromHex('#45556C'),
                  ),
                  _buildPdfChip(
                    '$lineCount lines',
                    background: PdfColor.fromHex('#F2F5F9'),
                    foreground: PdfColor.fromHex('#6B7280'),
                  ),
                  if (file.isLarge)
                    _buildPdfChip(
                      'Large file',
                      background: PdfColor.fromHex('#FEF3C7'),
                      foreground: PdfColor.fromHex('#92400E'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildPdfChip(
  String label, {
  required PdfColor background,
  required PdfColor foreground,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: pw.BoxDecoration(
      color: background,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        color: foreground,
        fontSize: 9.5,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}

PdfColor _pdfLanguageAccent(String language) {
  return switch (language.toLowerCase()) {
    'html' => PdfColor.fromHex('#E44D26'),
    'css' => PdfColor.fromHex('#2965F1'),
    'javascript' || 'js' => PdfColor.fromHex('#D4A017'),
    'typescript' || 'ts' => PdfColor.fromHex('#3178C6'),
    'dart' => PdfColor.fromHex('#0C7EBF'),
    'python' || 'py' => PdfColor.fromHex('#3B82F6'),
    'json' => PdfColor.fromHex('#16A34A'),
    _ => PdfColor.fromHex('#64748B'),
  };
}

List<pw.Widget> _buildPdfCodeSegmentWidgets(String codeBlock) {
  final cappedBlock = _truncateForPdf(codeBlock, _pdfMaxCodeCharacters);
  final parsed = parseCodeBlock(cappedBlock);
  if (looksLikeHtmlCode(parsed.code, parsed.language)) {
    return _buildPdfHtmlPreviewWidgets(parsed);
  }
  return _buildPdfCodeBlockWidgets(cappedBlock);
}

List<pw.Widget> _buildPdfHtmlPreviewWidgets(ParsedCodeBlock block) {
  final preview = buildHtmlPreviewModel(block.code);
  final previewText = _extractPdfHtmlPreviewText(preview.renderHtml);
  final widgets = <pw.Widget>[
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF7ED'),
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromHex('#FDBA74')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EA580C'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'HTML PREVIEW',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9.2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'Exported as a safe static preview',
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#9A3412'),
                  fontSize: 10.2,
                ),
              ),
            ],
          ),
          if (preview.title != null && preview.title!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              preview.title!,
              style: pw.TextStyle(
                color: PdfColor.fromHex('#7C2D12'),
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    ),
  ];

  if (previewText.isNotEmpty) {
    widgets.addAll(_buildPdfTextSegmentWidgets(previewText));
  } else {
    widgets.add(
      pw.Text(
        preview.emptyMessage,
        style: pw.TextStyle(
          color: PdfColor.fromHex('#6B7280'),
          fontSize: 11,
        ),
      ),
    );
  }

  if (preview.removedInteractiveContent) {
    widgets.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F8FAFC'),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex('#D7E0EA')),
        ),
        child: pw.Text(
          'Interactive browser-only sections were simplified in the PDF export.',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#475569'),
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }

  return widgets;
}

String _extractPdfHtmlPreviewText(String html) {
  if (html.trim().isEmpty) {
    return '';
  }
  final document = html_parser.parse(html);
  final text = document.documentElement?.text ?? '';
  return _truncateForPdf(
    _softWrapForPdf(
      text
          .replaceAll(RegExp(r'\s+\n'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
          .trim(),
    ),
    _pdfMaxHtmlPreviewCharacters,
  );
}

List<pw.Widget> _buildPdfTextSegmentWidgets(String segment) {
  final prepared = segment
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .trim();
  if (prepared.isEmpty) {
    return const [];
  }

  final mathChunks = _splitPdfMathMarkdown(prepared);
  final widgets = <pw.Widget>[];
  for (final chunk in mathChunks) {
    if (chunk.isDisplayMath) {
      widgets.add(
        _buildPdfMathWidget(chunk.content),
      );
      continue;
    }
    widgets.addAll(_buildPdfStructuredTextWidgets(chunk.content));
  }
  return widgets;
}

List<pw.Widget> _buildPdfStructuredTextWidgets(String prepared) {
  final widgets = <pw.Widget>[];
  final paragraphBuffer = <String>[];
  final lines = prepared.split('\n');

  void flushParagraph() {
    if (paragraphBuffer.isEmpty) {
      return;
    }
    widgets.addAll(
      _buildPdfParagraphWidgets(
        paragraphBuffer.join('\n'),
      ),
    );
    paragraphBuffer.clear();
  }

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }

    final headingMatch =
        RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(trimmed);
    if (headingMatch != null) {
      flushParagraph();
      widgets.add(
        _buildPdfHeadingWidget(
          headingMatch.group(2)!,
          level: headingMatch.group(1)!.length,
        ),
      );
      continue;
    }

    if (RegExp(r'^\|.*\|$').hasMatch(trimmed)) {
      flushParagraph();
      final tableLines = <String>[trimmed];
      while (index + 1 < lines.length &&
          RegExp(r'^\|.*\|$').hasMatch(lines[index + 1].trim())) {
        index += 1;
        tableLines.add(lines[index].trim());
      }
      widgets.addAll(_buildPdfTableWidgets(tableLines));
      continue;
    }

    if (trimmed.startsWith('>')) {
      flushParagraph();
      final quoteLines = <String>[trimmed];
      while (index + 1 < lines.length &&
          lines[index + 1].trim().startsWith('>')) {
        index += 1;
        quoteLines.add(lines[index].trim());
      }
      widgets.add(
        _buildPdfQuoteWidget(
          quoteLines
              .map((item) => item.replaceFirst(RegExp(r'^>\s?'), ''))
              .join('\n'),
        ),
      );
      continue;
    }

    if (RegExp(r'^([-*+]|\d+\.)\s+').hasMatch(trimmed)) {
      flushParagraph();
      final bulletText =
          trimmed.replaceFirst(RegExp(r'^([-*+]|\d+\.)\s+'), '');
      widgets.add(_buildPdfListItemWidget(bulletText));
      continue;
    }

    paragraphBuffer.add(line);
  }

  flushParagraph();
  return widgets;
}

class _PdfMathChunk {
  const _PdfMathChunk.text(this.content) : isDisplayMath = false;

  const _PdfMathChunk.displayMath(this.content) : isDisplayMath = true;

  final String content;
  final bool isDisplayMath;
}

List<_PdfMathChunk> _splitPdfMathMarkdown(String input) {
  final matches = RegExp(
    r'(\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\])',
    multiLine: true,
  ).allMatches(input);
  if (matches.isEmpty) {
    return [_PdfMathChunk.text(input)];
  }

  final chunks = <_PdfMathChunk>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      chunks.add(_PdfMathChunk.text(input.substring(cursor, match.start)));
    }
    chunks.add(
      _PdfMathChunk.displayMath(
        _stripPdfMathDelimiters(match.group(0)!),
      ),
    );
    cursor = match.end;
  }
  if (cursor < input.length) {
    chunks.add(_PdfMathChunk.text(input.substring(cursor)));
  }
  return chunks.where((chunk) => chunk.content.trim().isNotEmpty).toList();
}

String _stripPdfMathDelimiters(String value) {
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

pw.Widget _buildPdfMathWidget(String expression) {
  final normalized = _softWrapForPdf(
    _convertLatexToPdfText(expression),
    width: 54,
  );
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('#F8FAFC'),
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColor.fromHex('#D6E0EA')),
    ),
    child: pw.Text(
      normalized,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 12.4,
        lineSpacing: 2.2,
        color: PdfColor.fromHex('#0F172A'),
      ),
    ),
  );
}

List<pw.Widget> _buildPdfParagraphWidgets(String input) {
  final normalized = _normalizePdfMessageText(input);
  if (normalized.isEmpty) {
    return const [];
  }
  final chunks = _chunkPdfText(
    normalized,
    maxChunkLength: _pdfBodyChunkLength,
  );
  return [
    for (final chunk in chunks)
      pw.Text(
        chunk,
        style: pw.TextStyle(
          fontSize: 11.5,
          lineSpacing: 2.2,
          color: PdfColor.fromHex('#1F2937'),
        ),
      ),
  ];
}

pw.Widget _buildPdfHeadingWidget(String text, {required int level}) {
  final normalized = _normalizePdfInlineText(text);
  final style = switch (level) {
    1 => pw.TextStyle(
        fontSize: 17,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#5B21B6'),
      ),
    2 => pw.TextStyle(
        fontSize: 15,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#B45309'),
      ),
    _ => pw.TextStyle(
        fontSize: 13.2,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#0F766E'),
      ),
  };
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(normalized, style: style),
  );
}

pw.Widget _buildPdfQuoteWidget(String text) {
  final normalized = _normalizePdfMessageText(text);
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromHex('#F8FAFC'),
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border(
        left: pw.BorderSide(
          color: PdfColor.fromHex('#60A5FA'),
          width: 3,
        ),
      ),
    ),
    child: pw.Text(
      normalized,
      style: pw.TextStyle(
        fontSize: 11.1,
        lineSpacing: 2,
        color: PdfColor.fromHex('#475569'),
      ),
    ),
  );
}

pw.Widget _buildPdfListItemWidget(String text) {
  final normalized = _normalizePdfInlineText(text);
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 1),
        child: pw.Text(
          '•',
          style: pw.TextStyle(
            color: PdfColor.fromHex('#2563EB'),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.SizedBox(width: 8),
      pw.Expanded(
        child: pw.Text(
          _softWrapForPdf(normalized),
          style: pw.TextStyle(
            fontSize: 11.5,
            lineSpacing: 2.1,
            color: PdfColor.fromHex('#1F2937'),
          ),
        ),
      ),
    ],
  );
}

List<pw.Widget> _buildPdfTableWidgets(List<String> lines) {
  final rows = lines
      .where(
        (line) =>
            !RegExp(r'^\s*\|?[\s:-]+(\|[\s:-]+)+\|?\s*$').hasMatch(line),
      )
      .map(_parsePdfTableRow)
      .where((row) => row.isNotEmpty)
      .toList();

  if (rows.isEmpty) {
    return _buildPdfParagraphWidgets(lines.join('\n'));
  }

  final widgets = <pw.Widget>[];
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    final isHeader = rowIndex == 0;
    widgets.add(
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: isHeader
              ? PdfColor.fromHex('#E8F1FF')
              : (rowIndex.isEven
                  ? PdfColor.fromHex('#F8FAFC')
                  : PdfColors.white),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColor.fromHex('#D6E0EA')),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var cellIndex = 0; cellIndex < row.length; cellIndex++)
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.only(
                    right: cellIndex == row.length - 1 ? 0 : 10,
                  ),
                  child: pw.Text(
                    _softWrapForPdf(row[cellIndex]),
                    style: pw.TextStyle(
                      fontSize: isHeader ? 10.8 : 10.6,
                      fontWeight: isHeader
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                      color: isHeader
                          ? PdfColor.fromHex('#1D4ED8')
                          : PdfColor.fromHex('#334155'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  return widgets;
}

List<String> _parsePdfTableRow(String line) {
  final trimmed = line.trim();
  final segments = trimmed
      .replaceAll(RegExp(r'^\|'), '')
      .replaceAll(RegExp(r'\|$'), '')
      .split('|')
      .map((cell) => _normalizePdfInlineText(cell))
      .where((cell) => cell.isNotEmpty)
      .toList();
  return segments;
}

List<pw.Widget> _buildPdfCodeBlockWidgets(String codeBlock) {
  final parsed = parseCodeBlock(codeBlock);
  final code = parsed.code.trimRight();
  final normalizedCode = _softWrapForPdf(
    code.isEmpty ? '(empty code block)' : code,
    width: 64,
  );
  final chunks = _chunkPdfText(
    normalizedCode,
    maxChunkLength: _pdfCodeChunkLength,
  );

  return [
    for (final chunk in chunks)
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#0F172A'),
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(
            color: PdfColor.fromHex('#1E293B'),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#172554'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                parsed.language.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 9.2,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#BFDBFE'),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(
                  fontSize: 9.5,
                  lineSpacing: 1.8,
                  color: PdfColor.fromHex('#E2E8F0'),
                  font: pw.Font.courier(),
                ),
                children: _buildPdfHighlightedCodeSpans(
                  chunk,
                  parsed.language,
                ),
              ),
            ),
          ],
        ),
      ),
  ];
}

List<pw.InlineSpan> _buildPdfHighlightedCodeSpans(
  String code,
  String language,
) {
  final spans = highlightCode(
    code,
    language,
    theme: _buildPdfCodeHighlightTheme(),
  );
  return spans
      .map(
        (span) => pw.TextSpan(
          text: span.text,
          style: pw.TextStyle(
            color: span.style?.color == null
                ? null
                : PdfColor.fromInt(span.style!.color!.toARGB32()),
            fontWeight: span.style?.fontWeight == FontWeight.bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            fontStyle: span.style?.fontStyle == FontStyle.italic
                ? pw.FontStyle.italic
                : pw.FontStyle.normal,
            font: pw.Font.courier(),
          ),
        ),
      )
      .toList();
}

Map<String, TextStyle> _buildPdfCodeHighlightTheme() {
  return const {
    'root': TextStyle(color: Color(0xFFE2E8F0)),
    'keyword': TextStyle(color: Color(0xFFD8B4FE)),
    'keyworddeclaration': TextStyle(color: Color(0xFFD8B4FE)),
    'keywordflow': TextStyle(color: Color(0xFFD8B4FE)),
    'built_in': TextStyle(color: Color(0xFF5EEAD4)),
    'type': TextStyle(color: Color(0xFF5EEAD4)),
    'literal': TextStyle(color: Color(0xFF93C5FD)),
    'number': TextStyle(color: Color(0xFFC4F1A3)),
    'string': TextStyle(color: Color(0xFFFFC089)),
    'string_': TextStyle(color: Color(0xFFFFC089)),
    'subst': TextStyle(color: Color(0xFFE2E8F0)),
    'comment': TextStyle(
      color: Color(0xFF93A6BE),
      fontStyle: FontStyle.italic,
    ),
    'doctag': TextStyle(color: Color(0xFF93A6BE)),
    'tag': TextStyle(color: Color(0xFF7DD3FC)),
    'name': TextStyle(color: Color(0xFF83E1FF)),
    'attr': TextStyle(color: Color(0xFFA9E2FF)),
    'attribute': TextStyle(color: Color(0xFFA9E2FF)),
    'selector': TextStyle(color: Color(0xFFFFE08A)),
    'selectorattr': TextStyle(color: Color(0xFFFFE08A)),
    'selectorclass': TextStyle(color: Color(0xFFFFE08A)),
    'selectorid': TextStyle(color: Color(0xFFFFE08A)),
    'variable': TextStyle(color: Color(0xFFB6D5FF)),
    'params': TextStyle(color: Color(0xFFB6D5FF)),
    'function': TextStyle(color: Color(0xFFFFE082)),
    'title': TextStyle(color: Color(0xFFFFE082)),
    'titlefunction': TextStyle(color: Color(0xFFFFE082)),
    'titleclass': TextStyle(color: Color(0xFF5EEAD4)),
    'regexp': TextStyle(color: Color(0xFFFF9F7C)),
    'meta': TextStyle(color: Color(0xFF93C5FD)),
    'symbol': TextStyle(color: Color(0xFFC4F1A3)),
    'deletion': TextStyle(color: Color(0xFFFFB39B)),
    'addition': TextStyle(color: Color(0xFFC4F1A3)),
    'link': TextStyle(color: Color(0xFF93A6BE)),
    'quote': TextStyle(color: Color(0xFF93A6BE)),
    'bullet': TextStyle(color: Color(0xFFFFE082)),
    'emphasis': TextStyle(fontStyle: FontStyle.italic),
    'strong': TextStyle(fontWeight: FontWeight.bold),
  };
}

String _normalizePdfMessageText(String input) {
  var normalized = input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</li>\s*<li[^>]*>', caseSensitive: false), '\n- ')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '')
      .replaceAll(RegExp(r'</?(ul|ol|p)[^>]*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'^\s*>\s?', multiLine: true),
        (_) => '',
      )
      .replaceAllMapped(
        RegExp(r'\|'),
        (_) => ' | ',
      );

  final lines = normalized.split('\n');
  final cleanedLines = <String>[];
  for (final line in lines) {
    final trimmed = line.trimRight();
    if (trimmed.trim().isEmpty) {
      if (cleanedLines.isNotEmpty && cleanedLines.last.isNotEmpty) {
        cleanedLines.add('');
      }
      continue;
    }

    // Drop markdown table separators like | --- | --- |
    if (RegExp(r'^\s*\|?[\s:-]+(\|[\s:-]+)+\|?\s*$').hasMatch(trimmed)) {
      continue;
    }

    cleanedLines.add(_normalizePdfInlineText(trimmed));
  }

  return _softWrapForPdf(
    cleanedLines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim(),
  );
}

String _normalizePdfInlineText(String input) {
  return _normalizePdfInlineMath(
    input
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAllMapped(
        RegExp(r'!\[([^\]]*)\]\(([^)]*)\)'),
        (match) => match.group(1)?.trim().isNotEmpty == true
            ? '[Image: ${match.group(1)}]'
            : '[Image]',
      )
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\(([^)]*)\)'),
        (match) => '${match.group(1)} (${match.group(2)})',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim(),
  );
}

String _normalizePdfInlineMath(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'\\\((.+?)\\\)'),
        (match) => _convertLatexToPdfText(match.group(1)!),
      )
      .replaceAllMapped(
        RegExp(r'(?<!\$)\$([^\$\n]+?)\$(?!\$)'),
        (match) => _convertLatexToPdfText(match.group(1)!),
      );
}

String _convertLatexToPdfText(String input) {
  var output = input.trim();

  while (RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}').hasMatch(output)) {
    output = output.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}'),
      (match) =>
          '(${_convertLatexToPdfText(match.group(1)!)} / ${_convertLatexToPdfText(match.group(2)!)} )',
    );
  }

  while (RegExp(r'\\sqrt\s*\{([^{}]+)\}').hasMatch(output)) {
    output = output.replaceAllMapped(
      RegExp(r'\\sqrt\s*\{([^{}]+)\}'),
      (match) => '√(${_convertLatexToPdfText(match.group(1)!)} )',
    );
  }

  output = output
      .replaceAll(r'\left', '')
      .replaceAll(r'\right', '')
      .replaceAllMapped(
        RegExp(r'\^\{([^{}]+)\}'),
        (match) => _toSuperscript(match.group(1)!),
      )
      .replaceAllMapped(
        RegExp(r'_\{([^{}]+)\}'),
        (match) => _toSubscript(match.group(1)!),
      )
      .replaceAllMapped(
        RegExp(r'\^([A-Za-z0-9+\-=()])'),
        (match) => _toSuperscript(match.group(1)!),
      )
      .replaceAllMapped(
        RegExp(r'_([A-Za-z0-9+\-=()])'),
        (match) => _toSubscript(match.group(1)!),
      );

  final replacements = <String, String>{
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\delta': 'δ',
    r'\epsilon': 'ε',
    r'\varepsilon': 'ε',
    r'\theta': 'θ',
    r'\lambda': 'λ',
    r'\mu': 'μ',
    r'\pi': 'π',
    r'\sigma': 'σ',
    r'\phi': 'φ',
    r'\omega': 'ω',
    r'\Gamma': 'Γ',
    r'\Delta': 'Δ',
    r'\Theta': 'Θ',
    r'\Lambda': 'Λ',
    r'\Pi': 'Π',
    r'\Sigma': 'Σ',
    r'\Phi': 'Φ',
    r'\Omega': 'Ω',
    r'\times': '×',
    r'\cdot': '·',
    r'\pm': '±',
    r'\mp': '∓',
    r'\neq': '≠',
    r'\ne': '≠',
    r'\leq': '≤',
    r'\geq': '≥',
    r'\approx': '≈',
    r'\sim': '∼',
    r'\to': '→',
    r'\rightarrow': '→',
    r'\leftarrow': '←',
    r'\leftrightarrow': '↔',
    r'\implies': '⇒',
    r'\iff': '⇔',
    r'\sum': '∑',
    r'\prod': '∏',
    r'\int': '∫',
    r'\infty': '∞',
    r'\partial': '∂',
    r'\nabla': '∇',
    r'\forall': '∀',
    r'\exists': '∃',
    r'\in': '∈',
    r'\notin': '∉',
    r'\subseteq': '⊆',
    r'\supseteq': '⊇',
    r'\subset': '⊂',
    r'\supset': '⊃',
    r'\cup': '∪',
    r'\cap': '∩',
    r'\land': '∧',
    r'\lor': '∨',
    r'\neg': '¬',
    r'\degree': '°',
    r'\circ': '∘',
  };
  replacements.forEach((key, value) {
    output = output.replaceAll(key, value);
  });

  output = output
      .replaceAllMapped(
        RegExp(r'\\text\s*\{([^{}]+)\}'),
        (match) => match.group(1)!,
      )
      .replaceAll(RegExp(r'\\mathrm|\\mathbf|\\mathit|\\displaystyle'), '')
      .replaceAll(RegExp(r'[{}]'), '')
      .replaceAll(RegExp(r'\\,|\\;|\\:|\\!'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  return output;
}

String _toSuperscript(String input) {
  const map = {
    '0': '⁰',
    '1': '¹',
    '2': '²',
    '3': '³',
    '4': '⁴',
    '5': '⁵',
    '6': '⁶',
    '7': '⁷',
    '8': '⁸',
    '9': '⁹',
    '+': '⁺',
    '-': '⁻',
    '=': '⁼',
    '(': '⁽',
    ')': '⁾',
    'n': 'ⁿ',
    'i': 'ⁱ',
  };
  return input.split('').map((char) => map[char] ?? '^$char').join();
}

String _toSubscript(String input) {
  const map = {
    '0': '₀',
    '1': '₁',
    '2': '₂',
    '3': '₃',
    '4': '₄',
    '5': '₅',
    '6': '₆',
    '7': '₇',
    '8': '₈',
    '9': '₉',
    '+': '₊',
    '-': '₋',
    '=': '₌',
    '(': '₍',
    ')': '₎',
    'a': 'ₐ',
    'e': 'ₑ',
    'h': 'ₕ',
    'i': 'ᵢ',
    'j': 'ⱼ',
    'k': 'ₖ',
    'l': 'ₗ',
    'm': 'ₘ',
    'n': 'ₙ',
    'o': 'ₒ',
    'p': 'ₚ',
    'r': 'ᵣ',
    's': 'ₛ',
    't': 'ₜ',
    'u': 'ᵤ',
    'v': 'ᵥ',
    'x': 'ₓ',
  };
  return input.split('').map((char) => map[char] ?? '_$char').join();
}

List<String> _chunkPdfText(
  String text, {
  required int maxChunkLength,
}) {
  if (text.length <= maxChunkLength) {
    return [text];
  }

  final chunks = <String>[];
  var start = 0;
  while (start < text.length) {
    var end = start + maxChunkLength;
    if (end >= text.length) {
      chunks.add(text.substring(start).trim());
      break;
    }

    final preferredBreak = text.lastIndexOf('\n', end);
    final safeBreak = preferredBreak > start + (maxChunkLength ~/ 3)
        ? preferredBreak
        : text.lastIndexOf(' ', end);
    if (safeBreak <= start) {
      chunks.add(text.substring(start, end).trim());
      start = end;
      continue;
    }

    chunks.add(text.substring(start, safeBreak).trim());
    start = safeBreak + 1;
  }

  return chunks.where((chunk) => chunk.isNotEmpty).toList();
}

String _softWrapForPdf(
  String input, {
  int width = _pdfSoftWrapWidth,
}) {
  final lines = input.split('\n');
  final buffer = StringBuffer();

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.length <= width) {
      buffer.write(line);
    } else {
      buffer.write(_wrapLongLineForPdf(line, width: width));
    }
    if (i != lines.length - 1) {
      buffer.write('\n');
    }
  }

  return buffer.toString();
}

String _wrapLongLineForPdf(
  String input, {
  required int width,
}) {
  final words = input.split(RegExp(r'(\s+)'));
  final buffer = StringBuffer();
  var currentLineLength = 0;

  for (final token in words) {
    if (token.isEmpty) {
      continue;
    }

    if (RegExp(r'^\s+$').hasMatch(token)) {
      if (currentLineLength > 0) {
        buffer.write(' ');
        currentLineLength += 1;
      }
      continue;
    }

    final safeWord = _breakPdfWord(token, width: width);
    final safeParts = safeWord.split('\n');
    for (var i = 0; i < safeParts.length; i++) {
      final part = safeParts[i];
      if (part.isEmpty) {
        continue;
      }

      final needsNewLine =
          currentLineLength > 0 && currentLineLength + part.length > width;
      if (needsNewLine) {
        buffer.write('\n');
        currentLineLength = 0;
      }
      buffer.write(part);
      currentLineLength += part.length;

      if (i != safeParts.length - 1) {
        buffer.write('\n');
        currentLineLength = 0;
      }
    }
  }

  return buffer.toString();
}

String _breakPdfWord(
  String input, {
  required int width,
}) {
  if (input.length <= width) {
    return input;
  }

  final pieces = <String>[];
  for (var index = 0; index < input.length; index += width) {
    final end = (index + width).clamp(0, input.length);
    pieces.add(input.substring(index, end));
  }
  return pieces.join('\n');
}

String _truncateForPdf(String input, int maxLength) {
  if (input.length <= maxLength) {
    return input;
  }
  final safeLength = maxLength < 32 ? maxLength : maxLength - 32;
  return '${input.substring(0, safeLength).trimRight()}\n\n[Content truncated for PDF export]';
}

Future<pw.ThemeData> _loadWorkspacePdfTheme() {
  return _cachedPdfTheme ??= () async {
    final regularFont =
        pw.Font.ttf(await rootBundle.load(_pdfFontRegularAsset));
    final boldFont = pw.Font.ttf(await rootBundle.load(_pdfFontBoldAsset));
    final emojiFont = pw.Font.ttf(await rootBundle.load(_pdfEmojiFontAsset));
    return pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
      fontFallback: [emojiFont],
    );
  }();
}

Future<void> showWorkspaceSidebarDialog({
  required BuildContext context,
  required TextEditingController searchController,
  ScrollController? scrollController,
  double initialScrollOffset = 0,
  ValueChanged<double>? onScrollOffsetChanged,
  required VoidCallback onSearchChanged,
  required VoidCallback onNewChat,
  required ValueChanged<String> onSelectChat,
  required VoidCallback onSelectHome,
  required VoidCallback onSelectSettings,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Sidebar',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) {
      return WorkspaceSidebarDialog(
        searchController: searchController,
        scrollController: scrollController,
        initialScrollOffset: initialScrollOffset,
        onScrollOffsetChanged: onScrollOffsetChanged,
        onSearchChanged: onSearchChanged,
        onNewChat: onNewChat,
        onSelectChat: onSelectChat,
        onSelectHome: onSelectHome,
        onSelectSettings: onSelectSettings,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return SlideTransition(position: offsetAnimation, child: child);
    },
  );
}

class WorkspaceSidebarDialog extends StatelessWidget {
  const WorkspaceSidebarDialog({
    super.key,
    required this.searchController,
    this.scrollController,
    this.initialScrollOffset = 0,
    this.onScrollOffsetChanged,
    required this.onSearchChanged,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onSelectHome,
    required this.onSelectSettings,
  });

  final TextEditingController searchController;
  final ScrollController? scrollController;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollOffsetChanged;
  final VoidCallback onSearchChanged;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelectChat;
  final VoidCallback onSelectHome;
  final VoidCallback onSelectSettings;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(10, 10, 36, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                media.size.width * 0.84 > 320 ? 320 : media.size.width * 0.84,
          ),
          child: Material(
            color: Colors.transparent,
            child: SidebarDrawer(
              compact: true,
              searchController: searchController,
              scrollController: scrollController,
              initialScrollOffset: initialScrollOffset,
              onScrollOffsetChanged: onScrollOffsetChanged,
              onSearchChanged: onSearchChanged,
              onNewChat: onNewChat,
              onSelectChat: onSelectChat,
              onSelectHome: onSelectHome,
              onSelectSettings: onSelectSettings,
            ),
          ),
        ),
      ),
    );
  }
}

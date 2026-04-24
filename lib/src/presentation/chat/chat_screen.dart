import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../components/app_ui.dart';
import '../components/message_item.dart';
import '../workspace/workspace_overlays.dart';
import 'chat_view_model.dart';

// ---------------------------------------------------------------------------
// Message wrapper with GlobalKey for scroll positioning
// ---------------------------------------------------------------------------
class _ChatEntry {
  _ChatEntry({required this.message, GlobalKey? key})
      : key = key ?? GlobalKey();
  final ChatMessage message;
  final GlobalKey key;
}

// ---------------------------------------------------------------------------
// ChatScreen
// ---------------------------------------------------------------------------
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.scrollController,
    required this.onOpenSidebar,
    required this.onEditMessage,
    required this.onPreviewHtml,
    required this.onDownloadHtml,
    required this.onOpenSandbox,
    required this.onExportChat,
    required this.showScrollToBottom,
    required this.onScrollToBottom,
  });

  final ScrollController scrollController;
  final VoidCallback onOpenSidebar;
  final ValueChanged<String> onEditMessage;
  final ValueChanged<String> onPreviewHtml;
  final ValueChanged<String> onDownloadHtml;
  final void Function(String code, String language) onOpenSandbox;
  final VoidCallback onExportChat;
  final bool showScrollToBottom;
  final VoidCallback onScrollToBottom;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final List<_ChatEntry> _entries = [];
  bool _isTyping = false;
  int _lastPersistedCount = 0;
  bool _isScrollingProgrammatically = false;
  bool _isUserTouchScrolling = false;
  bool _userScrolledToPause = false;
  double _computedBottomPadding = 20.0;
  Object? _lastBottomPaddingSignature;
  bool _autoScrollScheduled = false;
  bool _paddingMeasureScheduled = false;

  /// Key on the ListView so we can measure its global top-Y position.
  final GlobalKey _listViewKey = GlobalKey();

  // ---------------------------------------------------------------------------
  // "Parda piche" scroll
  // ---------------------------------------------------------------------------
  /// Scrolls the message at [index] to sit exactly at the top of the
  /// ListView viewport (just below the GidarTopBar).
  ///
  /// Formula:
  ///   targetOffset = sc.offset + (messageScreenY - listViewScreenY)
  ///
  /// Both values are measured in global screen coordinates so the result is
  /// accurate on any device regardless of status-bar or top-bar height.
  void _scrollMessageToTop(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index >= _entries.length) return;

      final sc = widget.scrollController;
      if (!sc.hasClients) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollMessageToTop(index));
        return;
      }

      final msgCtx = _entries[index].key.currentContext;
      if (msgCtx == null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollMessageToTop(index));
        return;
      }
      final msgBox = msgCtx.findRenderObject() as RenderBox?;
      if (msgBox == null || !msgBox.hasSize) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollMessageToTop(index));
        return;
      }

      final listCtx = _listViewKey.currentContext;
      if (listCtx == null) return;
      final listBox = listCtx.findRenderObject() as RenderBox?;
      if (listBox == null) return;

      final messageScreenY = msgBox.localToGlobal(Offset.zero).dy;
      final listViewScreenY = listBox.localToGlobal(Offset.zero).dy;

      final targetOffset = (sc.offset + messageScreenY - listViewScreenY)
          .clamp(0.0, sc.position.maxScrollExtent);

      _isScrollingProgrammatically = true;
      sc
          .animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      )
          .whenComplete(() {
        _isScrollingProgrammatically = false;
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Streaming autoscroll
  // ---------------------------------------------------------------------------
  /// Called every build frame while the AI is streaming.
  /// Keeps the view pinned to the growing response.
  void _autoscrollIfNeeded(double viewportHeight) {
    if (_autoScrollScheduled) return;
    _autoScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollScheduled = false;
      if (!mounted || !_isTyping) return;
      if (_userScrolledToPause || _isUserTouchScrolling) return;
      final sc = widget.scrollController;
      if (!sc.hasClients || _isScrollingProgrammatically) return;

      final target = _contentTargetFor(
        maxScrollExtent: sc.position.maxScrollExtent,
        viewportHeight: viewportHeight,
      );
      if ((target - sc.offset).abs() <= 1.0) return;
      if (target < sc.offset) return;
      sc.jumpTo(target);
    });
  }

  // ---------------------------------------------------------------------------
  // Padding Calculator
  // ---------------------------------------------------------------------------
  /// Dynamically measures exactly how much bottom padding is required to allow
  /// the latest user message to touch the top of the viewport.
  void _calculateIdealBottomPadding({
    required double viewportHeight,
    required double keyboardInset,
    required bool isStreaming,
  }) {
    if (_entries.isEmpty) return;

    int userMsgIndex = -1;
    for (int i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].message.role == 'user') {
        userMsgIndex = i;
        break;
      }
    }

    final targetIndex = userMsgIndex >= 0 ? userMsgIndex : 0;
    final signature = Object.hash(
      _entries.length,
      _entries.last.message.id,
      _entries[targetIndex].message.id,
      viewportHeight.round(),
      keyboardInset.round(),
    );
    if (!isStreaming && signature == _lastBottomPaddingSignature) return;
    _lastBottomPaddingSignature = signature;
    if (_paddingMeasureScheduled) return;
    _paddingMeasureScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paddingMeasureScheduled = false;
      if (!mounted || _entries.isEmpty) return;
      if (targetIndex >= _entries.length) return;

      final targetCtx = _entries[targetIndex].key.currentContext;
      final targetBox = targetCtx?.findRenderObject() as RenderBox?;
      if (targetBox == null) return;

      final listCtx = _listViewKey.currentContext;
      final listBox = listCtx?.findRenderObject() as RenderBox?;
      if (listBox == null) return;

      final lastCtx = _entries.last.key.currentContext;
      final lastBox = lastCtx?.findRenderObject() as RenderBox?;
      if (lastBox == null) return;

      final viewportHeight = listBox.size.height;

      final targetY = targetBox.localToGlobal(Offset.zero).dy;
      final lastBottomY =
          lastBox.localToGlobal(Offset(0, lastBox.size.height)).dy;

      // The vertical distance from the top of the Target Message to the absolute bottom of the chat
      final contentBelowTarget = lastBottomY - targetY;

      // The padding required to bridge the gap if the content is smaller than viewport
      final requiredPadding = viewportHeight - contentBelowTarget;
      final finalPadding = requiredPadding < 20.0 ? 20.0 : requiredPadding;

      if ((_computedBottomPadding - finalPadding).abs() > 2.0) {
        if (_isTyping) {
          // SILENT UPDATE: Update the padding value locally without triggering a setState loop.
          // This entirely prevents the CPU lag while guaranteeing the correct value is ready
          // exactly when the stream stops!
          _computedBottomPadding = finalPadding;
        } else {
          setState(() {
            _computedBottomPadding = finalPadding;
          });
        }
      }
    });
  }

  double _contentTargetFor({
    required double maxScrollExtent,
    required double viewportHeight,
  }) {
    return (maxScrollExtent - viewportHeight + 60.0).clamp(
      0.0,
      maxScrollExtent,
    );
  }

  bool _isNearBottom(
    ScrollController controller, {
    double viewportHeight = 0,
    double tolerance = 56.0,
  }) {
    if (!controller.hasClients || !controller.position.hasContentDimensions) {
      return true;
    }
    final target = _contentTargetFor(
      maxScrollExtent: controller.position.maxScrollExtent,
      viewportHeight: viewportHeight <= 0
          ? controller.position.viewportDimension
          : viewportHeight,
    );
    return (target - controller.offset).abs() <= tolerance ||
        controller.offset > target;
  }

  void _stopProgrammaticScroll() {
    final sc = widget.scrollController;
    if (!sc.hasClients) return;
    if (_isScrollingProgrammatically) {
      sc.jumpTo(sc.offset);
      _isScrollingProgrammatically = false;
    }
  }

  void _pauseAutoScroll() {
    _isUserTouchScrolling = true;
    _userScrolledToPause = true;
    _stopProgrammaticScroll();
  }

  void _resumeAutoScrollIfNearBottom(double viewportHeight) {
    _isUserTouchScrolling = false;
    if (_isNearBottom(widget.scrollController,
        viewportHeight: viewportHeight)) {
      _userScrolledToPause = false;
    }
  }

  void _syncPersistedEntries(
    List<ChatMessage> messages, {
    GlobalKey? trailingAssistantKey,
  }) {
    final existingKeys = <String, GlobalKey>{};
    for (final entry in _entries) {
      if (entry.message.id != 'streaming') {
        existingKeys[entry.message.id] = entry.key;
      }
    }

    if (trailingAssistantKey != null && messages.isNotEmpty) {
      final lastMessage = messages.last;
      if (lastMessage.role == 'assistant' &&
          !existingKeys.containsKey(lastMessage.id)) {
        existingKeys[lastMessage.id] = trailingAssistantKey;
      }
    }

    _entries
      ..clear()
      ..addAll(
        messages.map(
          (message) => _ChatEntry(
            message: message,
            key: existingKeys[message.id],
          ),
        ),
      );
    _lastPersistedCount = messages.length;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(chatViewModelProvider);
    final actions = ref.watch(chatActionsProvider);
    final controller = ref.read(appControllerProvider);
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    final activeProviderLabel = ref.watch(
      appControllerProvider.select((value) => value.activeProviderLabel),
    );
    final session = vm.session;
    final isStarred = session?.isStarred ?? false;
    final hasActiveStreaming =
        controller.isWaitingForAssistant || controller.isTypingAssistant;
    final isStreaming =
        hasActiveStreaming && controller.streamingSessionId == session?.id;
    final editableUserMessageId = !hasActiveStreaming
        ? vm.messages
            .lastWhere(
              (message) => message.role == 'user',
              orElse: () => ChatMessage(
                id: '',
                role: 'system',
                content: '',
                createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              ),
            )
            .id
        : null;
    final draft = controller.streamingDraft;
    final trailingStreamingKey =
        _entries.isNotEmpty && _entries.last.message.id == 'streaming'
            ? _entries.last.key
            : null;

    // ---- Sync persisted messages ----
    if (vm.messages.length != _lastPersistedCount) {
      _syncPersistedEntries(
        vm.messages,
        trailingAssistantKey: !isStreaming ? trailingStreamingKey : null,
      );
    }

    // ---- Streaming just started ----
    if (isStreaming && !_isTyping) {
      _userScrolledToPause = false; // reset when a new message goes out
      // Scroll the user's message to the top ("parda piche").
      final userMsgIndex = _entries.length - 1;
      _scrollMessageToTop(userMsgIndex);

      // Add a transient streaming placeholder.
      _entries.add(_ChatEntry(
        message: ChatMessage(
          id: 'streaming',
          role: 'assistant',
          content: '',
          createdAt: DateTime.now(),
        ),
      ));
    }

    // ---- Streaming active: update placeholder content ----
    if (isStreaming && _entries.isNotEmpty) {
      if (_entries.last.message.id == 'streaming') {
        final oldKey = _entries.last.key;
        _entries[_entries.length - 1] = _ChatEntry(
          message: ChatMessage(
            id: 'streaming',
            role: 'assistant',
            content: draft,
            createdAt: DateTime.now(),
          ),
          key: oldKey,
        );
      }
    }

    // ---- Streaming ended: replace placeholder with persisted AI reply ----
    if (!isStreaming && _isTyping) {
      if (_entries.isNotEmpty && _entries.last.message.id == 'streaming') {
        _entries.removeLast();
      }
      _syncPersistedEntries(vm.messages);
    }

    _isTyping = isStreaming;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Column(
        children: [
          GidarTopBar(
            title: activeProviderLabel,
            onLeadingTap: widget.onOpenSidebar,
            trailing: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: tokens.mutedForeground.withValues(alpha: 0.85),
                size: 20,
              ),
              onSelected: (value) =>
                  _handleMenuAction(value, actions, controller),
              color: tokens.modalSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'export',
                  child:
                      _menuRow(Icons.picture_as_pdf_rounded, 'Export as PDF'),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: _menuRow(Icons.ios_share_rounded, 'Share'),
                ),
                PopupMenuItem(
                  value: 'copy_text',
                  child: _menuRow(Icons.copy_all_rounded, 'Copy as Text'),
                ),
                PopupMenuItem(
                  value: 'starred',
                  child: _menuRow(
                    isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                    isStarred ? 'Unstar Chat' : 'Star Chat',
                    color: isStarred ? const Color(0xFFFFC107) : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Bottom padding is massive during streaming so new messages smoothly
                // push everything out of sight ("parda piche" scroll).
                // When done, it snaps exactly to the _computedBottomPadding, locking the view.
                final dynamicBottom = isStreaming
                    ? constraints.maxHeight - 8.0
                    : _computedBottomPadding;
                _calculateIdealBottomPadding(
                  viewportHeight: constraints.maxHeight,
                  keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
                  isStreaming: isStreaming,
                );

                // Calculate the exact offset where the last message's bottom
                // sits just inside the viewport (plus 60px margin).
                final sc = widget.scrollController;
                if (isStreaming && _isTyping) {
                  _autoscrollIfNeeded(constraints.maxHeight);
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: vm.session == null
                          ? Center(
                              child: Text(
                                'Open a chat or start a new one.',
                                style: typography.chatMeta.copyWith(
                                  color: tokens.mutedForeground,
                                ),
                              ),
                            )
                          : ScrollConfiguration(
                              behavior: const MaterialScrollBehavior().copyWith(
                                overscroll: false,
                                scrollbars: false,
                              ),
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  if (notification is ScrollStartNotification &&
                                      notification.dragDetails != null) {
                                    _pauseAutoScroll();
                                  }
                                  if (notification
                                      is ScrollUpdateNotification) {
                                    if (notification.dragDetails != null &&
                                        !_isNearBottom(
                                          sc,
                                          viewportHeight: constraints.maxHeight,
                                          tolerance: 24,
                                        )) {
                                      _pauseAutoScroll();
                                    }
                                    if (_isNearBottom(
                                      sc,
                                      viewportHeight: constraints.maxHeight,
                                    )) {
                                      _userScrolledToPause = false;
                                    }
                                  }
                                  if (notification is UserScrollNotification &&
                                      notification.direction !=
                                          ScrollDirection.idle &&
                                      !_isNearBottom(
                                        sc,
                                        viewportHeight: constraints.maxHeight,
                                        tolerance: 24,
                                      )) {
                                    _pauseAutoScroll();
                                  }
                                  if (notification is ScrollEndNotification) {
                                    _resumeAutoScrollIfNearBottom(
                                      constraints.maxHeight,
                                    );
                                  }
                                  return false;
                                },
                                child: ListView.builder(
                                  key: _listViewKey,
                                  controller: widget.scrollController,
                                  physics: const RangeMaintainingScrollPhysics(
                                    parent: ClampingScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.only(
                                      top: 8, bottom: dynamicBottom),
                                  itemCount: _entries.length,
                                  itemBuilder: (context, index) {
                                    final entry = _entries[index];
                                    return AnimatedMessageEntry(
                                      key: entry.key,
                                      child: _ChatBubble(
                                        message: entry.message,
                                        isStreaming: isStreaming,
                                        canEdit: entry.message.id ==
                                            editableUserMessageId,
                                        controller: controller,
                                        actions: actions,
                                        onEditMessage: widget.onEditMessage,
                                        onPreviewHtml: widget.onPreviewHtml,
                                        onDownloadHtml: widget.onDownloadHtml,
                                        onOpenSandbox: widget.onOpenSandbox,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 16,
                      child: AnimatedBuilder(
                        animation: sc,
                        builder: (context, child) {
                          final fabTarget =
                              sc.hasClients && sc.position.hasContentDimensions
                                  ? (sc.position.maxScrollExtent -
                                          constraints.maxHeight +
                                          60.0)
                                      .clamp(0.0, sc.position.maxScrollExtent)
                                  : 0.0;
                          final showFab = sc.hasClients &&
                              sc.position.hasContentDimensions &&
                              _entries.length > 1 &&
                              sc.offset < fabTarget - 150;
                          return ScrollToBottomFab(
                            visible: showFab,
                            onTap: () {
                              _userScrolledToPause = false;
                              _isUserTouchScrolling = false;
                              _stopProgrammaticScroll();
                              if (sc.hasClients) {
                                _isScrollingProgrammatically = true;
                                sc
                                    .animateTo(
                                  fabTarget,
                                  duration: const Duration(milliseconds: 380),
                                  curve: Curves.easeOutCubic,
                                )
                                    .whenComplete(() {
                                  _isScrollingProgrammatically = false;
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuRow(IconData icon, String label, {Color? color}) {
    final tokens = context.appThemeTokens;
    final typography = context.appTypography;
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? tokens.mutedForeground),
        const SizedBox(width: 10),
        Text(
          label,
          style: typography.menuLabel.copyWith(
            color: color ?? tokens.foreground,
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuAction(
    String action,
    ChatActions actions,
    dynamic controller,
  ) async {
    switch (action) {
      case 'export':
        await Future<void>.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
        widget.onExportChat();
        break;
      case 'share':
        final session = controller.selectedSession;
        if (session != null) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
          if (!mounted) return;
          await shareChatSessionPdf(
            context: context,
            session: session,
            modelName: controller.selectedModel?.name ?? 'No model selected',
          );
        }
        break;
      case 'copy_text':
        final text = actions.getChatAsText();
        if (text != null && text.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: text));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Chat copied to clipboard'),
              duration: const Duration(seconds: 2),
              backgroundColor: context.appThemeTokens.modalSurface,
            ),
          );
        }
        break;
      case 'starred':
        await actions.toggleStarred();
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// ChatBubble — renders either user or assistant message
// ---------------------------------------------------------------------------
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isStreaming,
    required this.canEdit,
    required this.controller,
    required this.actions,
    required this.onEditMessage,
    required this.onPreviewHtml,
    required this.onDownloadHtml,
    required this.onOpenSandbox,
  });

  final ChatMessage message;
  final bool isStreaming;
  final bool canEdit;
  final dynamic controller;
  final ChatActions actions;
  final ValueChanged<String> onEditMessage;
  final ValueChanged<String> onPreviewHtml;
  final ValueChanged<String> onDownloadHtml;
  final void Function(String code, String language) onOpenSandbox;

  @override
  Widget build(BuildContext context) {
    if (message.role == 'user') {
      return UserMessageBubble(
        message: message,
        onEdit: canEdit ? () => onEditMessage(message.id) : null,
      );
    }

    final isTransient = message.id == 'streaming';
    return AssistantMessageCard(
      message: message,
      isGenerating: isTransient && isStreaming,
      isWaitingForResponse: isTransient && controller.isWaitingForAssistant,
      onCopy: actions.copyLastAssistantMessage,
      onRetry: actions.retryLastAssistantMessage,
      onPreviewHtml: onPreviewHtml,
      onDownloadHtml: onDownloadHtml,
      onOpenSandbox: onOpenSandbox,
      onThumbUp: isTransient
          ? null
          : () => actions.setAssistantFeedback(
                message.id,
                MessageFeedback.up,
              ),
      onThumbDown: isTransient
          ? null
          : () => actions.setAssistantFeedback(
                message.id,
                MessageFeedback.down,
              ),
    );
  }
}

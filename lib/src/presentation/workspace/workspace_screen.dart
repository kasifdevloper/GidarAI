import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../chat/chat_screen.dart';
import '../components/toast_overlay.dart';
import '../settings/settings_screen.dart';
import '../sidebar/sidebar_drawer.dart';
import 'workspace_composer_controller.dart';
import 'workspace_overlays.dart';
import 'workspace_sheets.dart';
import 'workspace_support_widgets.dart';
import '../../core/theme/app_theme.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({
    super.key,
    this.settingsSection = SettingsSection.overview,
  });

  final SettingsSection settingsSection;

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  late final TextEditingController _searchController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _systemPromptController;
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _sidebarScrollController = ScrollController();
  bool _obscureApiKey = true;
  bool _showScrollToBottom = false;
  double _sidebarScrollOffset = 0;
  final Map<String, double> _modelPickerScrollOffsets = <String, double>{};
  AppToastData? _toast;
  Timer? _toastTimer;
  Timer? _backExitTimer;
  String _lastHydratedApiKey = '';
  String _lastHydratedSystemPrompt = '';
  String? _queuedErrorToast;
  String? _queuedStatusToast;
  bool _exitArmed = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _apiKeyController = TextEditingController();
    _systemPromptController = TextEditingController();
    _chatScrollController.addListener(_handleChatScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    _toastTimer?.cancel();
    _backExitTimer?.cancel();
    _chatScrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  void _handleChatScroll() {
    if (!_chatScrollController.hasClients) return;
    final distance = _chatScrollController.position.maxScrollExtent -
        _chatScrollController.offset;
    final shouldShow = distance > 220;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex =
        ref.watch(appControllerProvider.select((value) => value.currentIndex));
    final errorMessage =
        ref.watch(appControllerProvider.select((value) => value.errorMessage));
    final statusMessage =
        ref.watch(appControllerProvider.select((value) => value.statusMessage));
    final apiKey =
        ref.watch(appControllerProvider.select((value) => value.apiKey));
    final systemPrompt = ref.watch(
      appControllerProvider.select((value) => value.systemPrompt),
    );
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= 980;
    if (_lastHydratedApiKey != apiKey) {
      _apiKeyController.text = apiKey;
      _lastHydratedApiKey = apiKey;
    }
    if (_lastHydratedSystemPrompt != systemPrompt) {
      _systemPromptController.text = systemPrompt;
      _lastHydratedSystemPrompt = systemPrompt;
    }
    if (errorMessage != null && errorMessage != _queuedErrorToast) {
      _queuedErrorToast = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = errorMessage;
        _showToast(message, AppToastTone.error);
        ref.read(appControllerProvider).dismissError();
        _queuedErrorToast = null;
      });
    }
    if (statusMessage != null && statusMessage != _queuedStatusToast) {
      _queuedStatusToast = statusMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = statusMessage;
        _showToast(message, AppToastTone.info);
        ref.read(appControllerProvider).dismissStatus();
        _queuedStatusToast = null;
      });
    }
    final interceptAndroidBack =
        !isDesktop && Theme.of(context).platform == TargetPlatform.android;

    return PopScope<Object?>(
      canPop: !interceptAndroidBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !interceptAndroidBack) return;
        _handleAndroidBackNavigation(currentIndex);
      },
      child: DecoratedBox(
        decoration: _background(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: isDesktop
              ? _buildDesktop(
                  context,
                  currentIndex: currentIndex,
                )
              : _buildMobile(
                  context,
                  currentIndex: currentIndex,
                ),
        ),
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context, {
    required int currentIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SidebarDrawer(
            searchController: _searchController,
            scrollController: _sidebarScrollController,
            initialScrollOffset: _sidebarScrollOffset,
            onScrollOffsetChanged: (offset) => _sidebarScrollOffset = offset,
            onSearchChanged: () => setState(() {}),
            onNewChat: () => _navigateTo(GidarRouteTab.home),
            onSelectChat: (_) => _navigateTo(GidarRouteTab.chat),
            onSelectHome: () => _navigateTo(GidarRouteTab.home),
            onSelectSettings: () => _navigateTo(GidarRouteTab.settings),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildCurrentScreen(
                          currentIndex: currentIndex,
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: WorkspaceComposer(
                          onSubmit: _handlePromptSubmit,
                          onImageTap: _pickImages,
                          onCameraTap: _captureCameraImage,
                          onAttachTap: _openAttachmentPicker,
                          onCommandsTap: _openCommandSheet,
                          onModelTap: _openModelPicker,
                          onProviderTap: _openProviderPicker,
                          onSelectCommand: _handleSlashCommandSelection,
                        ),
                      ),
                      if (_toast case final toast?) ToastOverlay(toast: toast),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 250,
                  child: DesktopUtilityRail(
                    onOpenModels: _openModelPicker,
                    onOpenSettings: () => _navigateTo(GidarRouteTab.settings),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(
    BuildContext context, {
    required int currentIndex,
  }) {
    final showComposer = currentIndex != GidarRouteTab.settings.tabIndex;
    return Stack(
      children: [
        SafeArea(
          bottom: !showComposer,
          child: Column(
            children: [
              Expanded(
                child: _buildCurrentScreen(
                  currentIndex: currentIndex,
                ),
              ),
              if (showComposer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: WorkspaceComposer(
                    onSubmit: _handlePromptSubmit,
                    onImageTap: _pickImages,
                    onCameraTap: _captureCameraImage,
                    onAttachTap: _openAttachmentPicker,
                    onCommandsTap: _openCommandSheet,
                    onModelTap: _openModelPicker,
                    onProviderTap: _openProviderPicker,
                    onSelectCommand: _handleSlashCommandSelection,
                  ),
                ),
            ],
          ),
        ),
        if (_toast case final toast?) ToastOverlay(toast: toast),
      ],
    );
  }

  Widget _buildCurrentScreen({
    required int currentIndex,
  }) {
    return IndexedStack(
      index: currentIndex,
      children: [
        HomeTab(
          onPromptSubmit: _handlePromptSubmit,
          onOpenSidebar: _openSidebar,
          onOpenSettings: () => _navigateTo(GidarRouteTab.settings),
          onOpenModels: _openModelPicker,
          onContinueLastChat: () => _navigateTo(GidarRouteTab.chat),
        ),
        ChatScreen(
          scrollController: _chatScrollController,
          onOpenSidebar: _openSidebar,
          onEditMessage: _handleEditMessage,
          onPreviewHtml: _showHtmlPreview,
          onDownloadHtml: _downloadHtml,
          onOpenSandbox: _openSandbox,
          onExportChat: _exportCurrentChatPdf,
          showScrollToBottom: _showScrollToBottom,
          onScrollToBottom: () {},
        ),
        SettingsScreen(
          apiKeyController: _apiKeyController,
          systemPromptController: _systemPromptController,
          obscureApiKey: _obscureApiKey,
          onToggleObscure: () =>
              setState(() => _obscureApiKey = !_obscureApiKey),
          onOpenSidebar: _openSidebar,
          section: widget.settingsSection,
          onOpenSection: _openSettingsSection,
        ),
      ],
    );
  }

  Future<void> _handlePromptSubmit() async {
    final controller = ref.read(appControllerProvider);
    final composer = ref.read(workspaceComposerControllerProvider);
    final actions = ref.read(chatActionsProvider);
    final prompt = composer.promptText.trim();
    if (prompt.isEmpty) return;
    if (WorkspaceComposerController.slashCommands.contains(prompt)) {
      await _handleSlashCommandSelection(prompt);
      return;
    }
    if (!controller.hasAnyEnabledProviderKey ||
        !controller.hasReachableProviderKeyForCurrentMode) {
      _showToast(
        'At least one usable provider key required. Opening Settings.',
        AppToastTone.error,
      );
      _navigateTo(GidarRouteTab.settings);
      return;
    }
    if (controller.selectedModel == null) {
      _showToast(
        'Fetch and select a model before sending a message.',
        AppToastTone.error,
      );
      _openModelPicker();
      return;
    }
    final submission = composer.buildSubmission(prompt);
    final editingMessageId = composer.editingMessageId;
    composer.clearAfterSubmit();
    if (controller.currentIndex == GidarRouteTab.home.tabIndex) {
      _navigateTo(GidarRouteTab.chat);
      unawaited(
        controller.startChat(
          submission.promptText,
          displayPrompt: submission.displayText,
          attachments: submission.attachments,
        ),
      );
    } else {
      if (editingMessageId != null) {
        unawaited(
          actions.sendEditedPrompt(
            editingMessageId,
            submission.promptText,
            displayPrompt: submission.displayText,
            attachments: submission.attachments,
          ),
        );
      } else {
        unawaited(
          actions.sendPrompt(
            submission.promptText,
            displayPrompt: submission.displayText,
            attachments: submission.attachments,
          ),
        );
      }
    }
  }

  Future<void> _handleEditMessage(String messageId) async {
    final draft =
        ref.read(chatActionsProvider).prepareLastUserMessageEdit(messageId);
    if (draft == null) return;
    final controller = ref.read(appControllerProvider);
    ChatMessage? message;
    for (final item
        in controller.selectedSession?.messages ?? const <ChatMessage>[]) {
      if (item.id == messageId) {
        message = item;
        break;
      }
    }
    if (message == null) return;
    final composer = ref.read(workspaceComposerControllerProvider);
    composer.beginEditingMessage(
      messageId: messageId,
      text: draft,
      attachments: composer.attachmentsFromChatAttachments(message.attachments),
    );
  }

  Future<void> _handleSlashCommandSelection(String command) async {
    ref.read(workspaceComposerControllerProvider).clearForSlashCommand();
    final controller = ref.read(appControllerProvider);
    final actions = ref.read(chatActionsProvider);
    switch (command) {
      case '/new':
        _navigateTo(GidarRouteTab.home);
        return;
      case '/clear':
        await controller.clearCurrentChat();
        return;
      case '/model':
        _openModelPicker();
        return;
      case '/settings':
        _navigateTo(GidarRouteTab.settings);
        return;
      case '/copy':
        await actions.copyLastAssistantMessage();
        return;
      case '/export':
        await _exportCurrentChatPdf();
        return;
      case '/help':
        _openCommandSheet();
        return;
    }
  }

  void _openCommandSheet() {
    showWorkspaceBottomSheet<void>(
      context,
      builder: (context) => WorkspaceCommandSheet(
        commands: WorkspaceComposerController.slashCommands,
        onSelected: (command) {
          _handleSlashCommandSelection(command);
        },
      ),
    );
  }

  void _openModelPicker() {
    final controller = ref.read(appControllerProvider);
    final provider = controller.selectedProvider;
    final customProviderId = controller.selectedCustomProviderId;
    final offsetKey = _modelPickerOffsetKey(
      provider,
      customProviderId: customProviderId,
    );
    final initialScrollOffset = _modelPickerScrollOffsets[offsetKey] ??
        controller.modelPickerScrollOffsetFor(
          provider,
          customProviderId: customProviderId,
        );
    showWorkspaceBottomSheet<void>(
      context,
      isScrollControlled: true,
      builder: (context) => WorkspaceModelPickerSheet(
        controller: controller,
        initialScrollOffset: initialScrollOffset,
        onScrollOffsetChanged: (offset) {
          _modelPickerScrollOffsets[offsetKey] = offset;
        },
      ),
    ).whenComplete(() {
      final latestOffset = _modelPickerScrollOffsets[offsetKey];
      if (latestOffset == null) return;
      unawaited(
        controller.saveModelPickerScrollOffset(
          provider,
          latestOffset,
          customProviderId: customProviderId,
        ),
      );
    });
  }

  void _openProviderPicker() {
    final controller = ref.read(appControllerProvider);
    showWorkspaceBottomSheet<void>(
      context,
      isScrollControlled: true,
      builder: (context) => WorkspaceProviderPickerSheet(
        controller: controller,
        onProviderSelected: (provider, customProviderId) {
          controller.selectProvider(
            provider,
            customProviderId: customProviderId,
          );
        },
      ),
    );
  }

  Future<void> _openAttachmentPicker() async {
    showWorkspaceBottomSheet<void>(
      context,
      builder: (context) => WorkspaceAttachmentPickerSheet(
        onPickImages: _pickImages,
      ),
    );
  }

  Future<void> _pickImages() async {
    final message =
        await ref.read(workspaceComposerControllerProvider).pickImages();
    if (message != null) {
      _showInfo(message);
    }
  }

  Future<void> _captureCameraImage() async {
    final message = await ref
        .read(workspaceComposerControllerProvider)
        .captureCameraImage();
    if (message != null) {
      _showInfo(message);
    }
  }

  void _showInfo(String message) {
    _showToast(message, AppToastTone.info);
  }

  void _showToast(String message, AppToastTone tone) {
    _toastTimer?.cancel();
    setState(() {
      _toast = AppToastData(message: message, tone: tone);
    });
    final seconds = switch (tone) {
      AppToastTone.error => message.length > 160 ? 6 : 5,
      AppToastTone.info => message.length > 120 ? 4 : 3,
      _ => 3,
    };
    _toastTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      setState(() => _toast = null);
    });
  }

  void _showHtmlPreview(String html) {
    showWorkspaceHtmlPreviewSheet(context, html);
  }

  void _openSandbox(String code, String language) {
    showWorkspaceCodeSandboxSheet(context, code, language);
  }

  Future<void> _downloadHtml(String html) async {
    final file = await saveWorkspaceHtmlPreview(html);
    _showToast('HTML saved to ${file.path}', AppToastTone.success);
  }

  Future<void> _exportCurrentChatPdf() async {
    final controller = ref.read(appControllerProvider);
    final session = controller.selectedSession;
    if (session == null) {
      _showToast('Open a chat to export it.', AppToastTone.neutral);
      return;
    }

    try {
      final savedPath = await saveChatSessionPdfLocally(
        context: context,
        session: session,
        modelName: controller.selectedModel?.name ?? 'No model selected',
      );
      _showToast('PDF saved to $savedPath', AppToastTone.success);
    } catch (_) {
      _showToast('Could not export this chat as PDF.', AppToastTone.info);
    }
  }

  void _navigateTo(
    GidarRouteTab tab, {
    bool preserveExitArm = false,
  }) {
    if (!preserveExitArm) {
      _disarmExit();
    }
    ref.read(appControllerProvider).setTab(tab.tabIndex);
    switch (tab) {
      case GidarRouteTab.home:
        context.goNamed('home');
        return;
      case GidarRouteTab.chat:
        context.goNamed('chat');
        return;
      case GidarRouteTab.settings:
        context.goNamed('settings');
        return;
    }
  }

  void _openSettingsSection(SettingsSection section) {
    _disarmExit();
    ref.read(appControllerProvider).setTab(GidarRouteTab.settings.tabIndex);
    switch (section) {
      case SettingsSection.overview:
        context.goNamed('settings');
        return;
      case SettingsSection.providers:
        context.goNamed('settings-providers');
        return;
      case SettingsSection.models:
        context.goNamed('settings-models');
        return;
      case SettingsSection.systemPrompt:
        context.goNamed('settings-systemPrompt');
        return;
      case SettingsSection.appearance:
        context.goNamed('settings-appearance');
        return;
      case SettingsSection.chatData:
        context.goNamed('settings-chatData');
        return;
      case SettingsSection.about:
        context.goNamed('settings-about');
        return;
    }
  }

  void _openSidebar() {
    showWorkspaceSidebarDialog(
      context: context,
      searchController: _searchController,
      scrollController: _sidebarScrollController,
      initialScrollOffset: _sidebarScrollOffset,
      onScrollOffsetChanged: (offset) => _sidebarScrollOffset = offset,
      onSearchChanged: () => setState(() {}),
      onNewChat: () {
        Navigator.pop(context);
        _navigateTo(GidarRouteTab.home);
      },
      onSelectChat: (_) {
        Navigator.pop(context);
        _navigateTo(GidarRouteTab.chat);
      },
      onSelectHome: () {
        Navigator.pop(context);
        _navigateTo(GidarRouteTab.home);
      },
      onSelectSettings: () {
        Navigator.pop(context);
        _navigateTo(GidarRouteTab.settings);
      },
    );
  }

  void _handleAndroidBackNavigation(int currentIndex) {
    if (currentIndex == GidarRouteTab.settings.tabIndex &&
        widget.settingsSection != SettingsSection.overview) {
      _openSettingsSection(SettingsSection.overview);
      return;
    }

    if (currentIndex != GidarRouteTab.home.tabIndex) {
      _navigateTo(GidarRouteTab.home);
      return;
    }

    if (_exitArmed) {
      SystemNavigator.pop();
      return;
    }

    _armExit();
  }

  void _armExit() {
    _backExitTimer?.cancel();
    if (!_exitArmed) {
      setState(() => _exitArmed = true);
    }
    _showToast('Press back again to exit.', AppToastTone.neutral);
    _backExitTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _exitArmed = false);
    });
  }

  void _disarmExit() {
    _backExitTimer?.cancel();
    if (!_exitArmed) return;
    setState(() => _exitArmed = false);
  }

  String _modelPickerOffsetKey(
    AiProviderType? provider, {
    String? customProviderId,
  }) {
    if (provider == AiProviderType.custom &&
        (customProviderId ?? '').trim().isNotEmpty) {
      return 'custom:${customProviderId!.trim()}';
    }
    return provider?.name ?? '__all__';
  }

  BoxDecoration _background(BuildContext context) {
    final tokens = context.appThemeTokens;
    return BoxDecoration(
      color: tokens.appBackground,
    );
  }
}

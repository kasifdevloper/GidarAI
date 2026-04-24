import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../components/app_ui.dart';
import '../home/home_screen.dart';
import '../home/home_view_model.dart';
import '../../core/theme/app_theme.dart';
import 'workspace_composer_controller.dart';

class DesktopUtilityRail extends ConsumerWidget {
  const DesktopUtilityRail({
    super.key,
    required this.onOpenModels,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenModels;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedModelName = ref.watch(
      appControllerProvider.select(
        (value) => value.selectedModel?.name ?? 'No model selected',
      ),
    );
    final showApiWarning = ref.watch(
      appControllerProvider.select((value) => !value.hasAnyEnabledProviderKey),
    );
    final activeProviderLabel = ref.watch(
      appControllerProvider.select((value) => value.activeProviderLabel),
    );
    final selectedProviderLabel = ref.watch(
      appControllerProvider.select((value) => value.selectedProviderLabel),
    );
    final enabledProviders = ref.watch(
      appControllerProvider.select((value) => value.enabledProviders.length),
    );

    return Column(
      children: [
        _RailCard(
          title: 'Workspace',
          children: [
            _RailStat(label: 'Active model', value: selectedModelName),
            const SizedBox(height: 10),
            _RailStat(label: 'Provider', value: activeProviderLabel),
            const SizedBox(height: 10),
            _RailStat(
              label: 'Filter',
              value: selectedProviderLabel,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _RailCard(
          title: 'Quick Actions',
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onOpenModels,
                child: const Text('Browse Models'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onOpenSettings,
                child: const Text('Open Settings'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _RailCard(
          title: 'Status',
          children: [
            _RailStat(label: 'Providers enabled', value: '$enabledProviders'),
            const SizedBox(height: 10),
            _RailStat(
              label: 'API state',
              value: showApiWarning ? 'Needs setup' : 'Ready',
              warning: showApiWarning,
            ),
          ],
        ),
      ],
    );
  }
}

class HomeTab extends ConsumerWidget {
  const HomeTab({
    super.key,
    required this.onPromptSubmit,
    required this.onOpenSidebar,
    required this.onOpenSettings,
    required this.onOpenModels,
    required this.onContinueLastChat,
  });

  final Future<void> Function() onPromptSubmit;
  final VoidCallback onOpenSidebar;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenModels;
  final VoidCallback onContinueLastChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(homeViewModelProvider);
    final showApiWarning = ref.watch(
      appControllerProvider.select((value) => !value.hasAnyEnabledProviderKey),
    );
    final promptController = ref.watch(
      workspaceComposerControllerProvider
          .select((value) => value.promptController),
    );
    return HomeScreen(
      promptController: promptController,
      onPromptSubmit: onPromptSubmit,
      onOpenSidebar: onOpenSidebar,
      onOpenSettings: onOpenSettings,
      onOpenModels: onOpenModels,
      onContinueLastChat: onContinueLastChat,
      showApiWarning: showApiWarning,
      vm: vm,
    );
  }
}

class WorkspaceComposer extends ConsumerWidget {
  const WorkspaceComposer({
    super.key,
    required this.onSubmit,
    required this.onImageTap,
    required this.onCameraTap,
    this.onFileTap,
    required this.onAttachTap,
    required this.onCommandsTap,
    required this.onModelTap,
    required this.onProviderTap,
    required this.onSelectCommand,
  });

  final Future<void> Function() onSubmit;
  final Future<void> Function() onImageTap;
  final Future<void> Function() onCameraTap;
  final Future<void> Function()? onFileTap;
  final VoidCallback onAttachTap;
  final VoidCallback onCommandsTap;
  final VoidCallback onModelTap;
  final VoidCallback onProviderTap;
  final ValueChanged<String> onSelectCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStreaming = ref.watch(
      appControllerProvider.select((value) => value.isStreaming),
    );
    final selectedModelLabel = ref.watch(
      appControllerProvider.select(
        (value) => value.selectedModel?.name ?? 'No model selected',
      ),
    );
    final selectedProviderLabel = ref.watch(
      appControllerProvider.select((value) => value.selectedProviderLabel),
    );
    final composer = ref.watch(workspaceComposerControllerProvider);
    return BottomPromptBar(
      controller: composer.promptController,
      onSubmit: onSubmit,
      isStreaming: isStreaming,
      onStop: ref.read(chatActionsProvider).stopStreaming,
      onImageTap: onImageTap,
      onCameraTap: onCameraTap,
      onFileTap: onFileTap,
      onAttachTap: onAttachTap,
      onCommandsTap: onCommandsTap,
      onModelTap: onModelTap,
      onProviderTap: onProviderTap,
      onToggleOptions: composer.toggleExpandedOptions,
      showExpandedOptions: composer.showExpandedOptions,
      selectedModelLabel: selectedModelLabel,
      selectedProviderLabel: selectedProviderLabel,
      attachments: composer.attachments,
      onRemoveAttachment: composer.removeAttachment,
      generateImageEnabled: composer.generateImage,
      generateDocumentEnabled: composer.generateDocument,
      webSearchEnabled: composer.webSearch,
      deepResearchEnabled: composer.deepResearch,
      activeModes: composer.activeModeLabels,
      isEditingLastMessage: composer.isEditingLastMessage,
      onCancelEditing: composer.cancelEditingMessage,
      onToggleGenerateImage: composer.toggleGenerateImage,
      onToggleGenerateDocument: composer.toggleGenerateDocument,
      onToggleWebSearch: composer.toggleWebSearch,
      onToggleDeepResearch: composer.toggleDeepResearch,
      showCommands: composer.showCommandPalette,
      commandOptions: composer.filteredCommands,
      onSelectCommand: onSelectCommand,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.modalSurface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            message,
            style: TextStyle(color: tokens.mutedForeground, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RailCard extends StatelessWidget {
  const _RailCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.panelSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _RailStat extends StatelessWidget {
  const _RailStat({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final String value;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.mutedForeground,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: warning ? const Color(0xFFFFB289) : tokens.foreground,
              ),
        ),
      ],
    );
  }
}

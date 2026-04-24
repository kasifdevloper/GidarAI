import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/app_descriptors.dart';
import '../../core/models/app_models.dart';
import '../../core/services/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../components/app_ui.dart';
import 'settings_actions.dart';
import 'settings_view_model.dart';

typedef SettingsSaveCallback = Future<void> Function({
  ModelOption? model,
  AppThemeMode? themeMode,
  AppAppearanceMode? appearanceMode,
  bool? dynamicThemeEnabled,
  ProviderKeys? providerKeys,
  CustomProviderConfig? customProvider,
  ChatRoutingMode? routingMode,
  List<AiProviderType>? enabledProviders,
  UiDensityMode? uiDensityMode,
  AppFontPreset? appFontPreset,
  AppFontPreset? chatFontPreset,
  ChatColorMode? chatColorMode,
});

class SettingsOverviewSection extends StatelessWidget {
  const SettingsOverviewSection({
    super.key,
    required this.vm,
    required this.theme,
    required this.onOpenSection,
  });

  final SettingsViewModel vm;
  final ThemeData theme;
  final ValueChanged<SettingsSection> onOpenSection;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        section: SettingsSection.providers,
        icon: Icons.key_rounded,
        title: 'Providers',
        subtitle: 'Keys, health, testing, and enabled providers',
      ),
      (
        section: SettingsSection.systemPrompt,
        icon: Icons.auto_awesome_rounded,
        title: 'System Prompt',
        subtitle: 'Prompt templates and custom instructions',
      ),
      (
        section: SettingsSection.appearance,
        icon: Icons.palette_rounded,
        title: 'Appearance',
        subtitle: 'Themes, fonts, chat colours, and density',
      ),
      (
        section: SettingsSection.chatData,
        icon: Icons.storage_rounded,
        title: 'Chat & Data',
        subtitle: 'Chat cleanup, cache reset, and destructive actions',
      ),
      (
        section: SettingsSection.about,
        icon: Icons.info_outline_rounded,
        title: 'About',
        subtitle: 'Version, stack summary, and app status',
      ),
    ];

    return Column(
      children: [
        SettingsBlock(
          child: Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Active Model',
                  value: vm.selectedModel?.name ?? 'No model selected',
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: 'Provider',
                  value: vm.selectedModel == null
                      ? 'All Providers'
                      : vm.providerLabelForModel(vm.selectedModel),
                  icon: Icons.hub_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Providers',
                  value: '${vm.enabledProviders.length} enabled',
                  icon: Icons.hub_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: 'Density',
                  value: vm.uiDensityMode == UiDensityMode.compact
                      ? 'Compact'
                      : 'Balanced',
                  icon: Icons.space_dashboard_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsLabel('SETTINGS SECTIONS'),
        const SizedBox(height: 12),
        ...cards.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SettingsNavCard(
              icon: item.icon,
              title: item.title,
              subtitle: item.subtitle,
              onTap: () => onOpenSection(item.section),
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsProvidersSection extends StatefulWidget {
  const SettingsProvidersSection({
    super.key,
    required this.vm,
    required this.controller,
    required this.actions,
    required this.saveSettings,
    required this.apiKeyController,
    required this.groqKeyController,
    required this.geminiKeyController,
    required this.cerebrasKeyController,
    required this.zAiKeyController,
    required this.mistralKeyController,
    required this.sambanovaKeyController,
    required this.customKeyController,
    required this.customProviderNameController,
    required this.customProviderBaseUrlController,
    required this.obscureApiKey,
    required this.onToggleObscure,
  });

  final SettingsViewModel vm;
  final AppController controller;
  final SettingsActions actions;
  final SettingsSaveCallback saveSettings;
  final TextEditingController apiKeyController;
  final TextEditingController groqKeyController;
  final TextEditingController geminiKeyController;
  final TextEditingController cerebrasKeyController;
  final TextEditingController zAiKeyController;
  final TextEditingController mistralKeyController;
  final TextEditingController sambanovaKeyController;
  final TextEditingController customKeyController;
  final TextEditingController customProviderNameController;
  final TextEditingController customProviderBaseUrlController;
  final bool obscureApiKey;
  final VoidCallback onToggleObscure;

  @override
  State<SettingsProvidersSection> createState() =>
      _SettingsProvidersSectionState();
}

class _ProviderSettingsTab {
  const _ProviderSettingsTab({
    required this.provider,
    required this.label,
    required this.enabled,
    this.customProviderId,
  });

  final AiProviderType provider;
  final String label;
  final bool enabled;
  final String? customProviderId;

  bool get isCustomProviderEntry =>
      provider == AiProviderType.custom &&
      (customProviderId ?? '').trim().isNotEmpty;
}

class _SettingsProvidersSectionState extends State<SettingsProvidersSection> {
  AiProviderType _selectedProvider = AiProviderType.openRouter;
  String? _selectedCustomProviderId;

  @override
  void initState() {
    super.initState();
    _selectedProvider = _resolveInitialProvider(widget.vm);
    _selectedCustomProviderId = _resolveInitialCustomProviderId(widget.vm);
  }

  @override
  void didUpdateWidget(covariant SettingsProvidersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibleProviders = _providerTabs().map((entry) => entry.provider);
    if (!visibleProviders.contains(_selectedProvider)) {
      _selectedProvider = _resolveInitialProvider(widget.vm);
    }
    if (_selectedProvider == AiProviderType.custom) {
      final selectedCustomProvider = findCustomProviderById(
        widget.controller.customProviders,
        _selectedCustomProviderId,
      );
      if (selectedCustomProvider == null) {
        _selectedCustomProviderId = _resolveInitialCustomProviderId(widget.vm);
      }
    } else {
      _selectedCustomProviderId = _resolveInitialCustomProviderId(widget.vm);
    }
  }

  AiProviderType _resolveInitialProvider(SettingsViewModel vm) {
    final currentProvider = vm.selectedModel?.provider;
    if (currentProvider != null &&
        (currentProvider != AiProviderType.custom ||
            vm.customProviders.isNotEmpty)) {
      return currentProvider;
    }
    if (vm.enabledProviders.isNotEmpty) {
      for (final provider in vm.enabledProviders) {
        if (AiProviderType.values.contains(provider)) {
          return provider;
        }
      }
    }
    return AiProviderType.values.first;
  }

  String? _resolveInitialCustomProviderId(SettingsViewModel vm) {
    final selectedModel = vm.selectedModel;
    if (selectedModel?.provider == AiProviderType.custom &&
        findCustomProviderById(
                vm.customProviders, selectedModel?.customProviderId) !=
            null) {
      return selectedModel!.customProviderId;
    }
    if (vm.customProviders.isNotEmpty) {
      return vm.customProviders.first.id;
    }
    return null;
  }

  List<_ProviderSettingsTab> _providerTabs() {
    final tabs = <_ProviderSettingsTab>[
      ...AiProviderType.values
          .where((provider) => provider != AiProviderType.custom)
          .map(
            (provider) => _ProviderSettingsTab(
              provider: provider,
              label: providerLabel(provider),
              enabled: widget.vm.enabledProviders.contains(provider),
            ),
          ),
    ];
    if (widget.controller.customProviders.isEmpty) {
      tabs.add(
        _ProviderSettingsTab(
          provider: AiProviderType.custom,
          label: 'Custom',
          enabled: widget.vm.enabledProviders.contains(AiProviderType.custom),
        ),
      );
      return tabs;
    }
    tabs.addAll(
      widget.controller.customProviders.map(
        (provider) => _ProviderSettingsTab(
          provider: AiProviderType.custom,
          label: provider.normalizedName,
          enabled: provider.enabled,
          customProviderId: provider.id,
        ),
      ),
    );
    return tabs;
  }

  TextEditingController _controllerFor(AiProviderType provider) {
    return switch (provider) {
      AiProviderType.openRouter => widget.apiKeyController,
      AiProviderType.groq => widget.groqKeyController,
      AiProviderType.gemini => widget.geminiKeyController,
      AiProviderType.cerebras => widget.cerebrasKeyController,
      AiProviderType.zAi => widget.zAiKeyController,
      AiProviderType.mistral => widget.mistralKeyController,
      AiProviderType.sambanova => widget.sambanovaKeyController,
      AiProviderType.custom => widget.customKeyController,
    };
  }

  @override
  Widget build(BuildContext context) {
    final providerTabs = _providerTabs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsLabel('AI PROVIDERS'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: providerTabs.map((tab) {
              final isSelected = tab.isCustomProviderEntry
                  ? _selectedProvider == AiProviderType.custom &&
                      _selectedCustomProviderId == tab.customProviderId
                  : tab.provider == _selectedProvider &&
                      (_selectedProvider != AiProviderType.custom ||
                          _selectedCustomProviderId == null);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _ProviderSelectorChip(
                  provider: tab.provider,
                  label: tab.label,
                  selected: isSelected,
                  enabled: tab.enabled,
                  onTap: () => setState(() {
                    _selectedProvider = tab.provider;
                    _selectedCustomProviderId = tab.customProviderId;
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _selectedProvider == AiProviderType.custom
              ? _CustomProvidersPanel(
                  vm: widget.vm,
                  controller: widget.controller,
                  saveSettings: widget.saveSettings,
                  selectedCustomProviderId: _selectedCustomProviderId,
                  onSelectedCustomProviderChanged: (customProviderId) {
                    setState(() {
                      _selectedProvider = AiProviderType.custom;
                      _selectedCustomProviderId = customProviderId;
                    });
                  },
                )
              : _ProviderDetailCard(
                  provider: _selectedProvider,
                  vm: widget.vm,
                  controller: widget.controller,
                  actions: widget.actions,
                  saveSettings: widget.saveSettings,
                  keyController: _controllerFor(_selectedProvider),
                  customNameController: widget.customProviderNameController,
                  customBaseUrlController:
                      widget.customProviderBaseUrlController,
                  onDeleteCustomProvider: null,
                  obscureApiKey: widget.obscureApiKey,
                  onToggleObscure: widget.onToggleObscure,
                ),
        ),
      ],
    );
  }
}

class _CustomProvidersPanel extends StatefulWidget {
  const _CustomProvidersPanel({
    required this.vm,
    required this.controller,
    required this.saveSettings,
    required this.selectedCustomProviderId,
    required this.onSelectedCustomProviderChanged,
  });

  final SettingsViewModel vm;
  final AppController controller;
  final SettingsSaveCallback saveSettings;
  final String? selectedCustomProviderId;
  final ValueChanged<String?> onSelectedCustomProviderChanged;

  @override
  State<_CustomProvidersPanel> createState() => _CustomProvidersPanelState();
}

class _CustomProvidersPanelState extends State<_CustomProvidersPanel> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelSearchController = TextEditingController();

  String _lastSyncedProviderId = '';
  String _modelSearchQuery = '';
  bool _obscureKey = true;
  bool _justSaved = false;
  bool _isFetchingModels = false;

  ButtonStyle _compactActionButtonStyle() {
    return FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  ButtonStyle _compactOutlineActionButtonStyle(BuildContext context) {
    final tokens = context.appThemeTokens;
    return OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: tokens.mutedBorder),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncControllersFromSelection();
  }

  @override
  void didUpdateWidget(covariant _CustomProvidersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromSelection();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelSearchController.dispose();
    super.dispose();
  }

  CustomProviderConfig? get _selectedCustomProvider {
    return findCustomProviderById(
      widget.controller.customProviders,
      widget.selectedCustomProviderId,
    );
  }

  void _syncControllersFromSelection() {
    final provider = _selectedCustomProvider;
    final providerId = provider?.id ?? '';
    if (_lastSyncedProviderId == providerId) return;
    _nameController.text = provider?.name ?? '';
    _baseUrlController.text = provider?.normalizedBaseUrl ?? '';
    _apiKeyController.text = provider?.apiKey ?? '';
    _lastSyncedProviderId = providerId;
  }

  String _nextCustomProviderId() {
    return 'custom-${DateTime.now().microsecondsSinceEpoch}';
  }

  List<ModelOption> _filterModels(List<ModelOption> models) {
    if (_modelSearchQuery.trim().isEmpty) return models;
    final query = _modelSearchQuery.toLowerCase();
    return models
        .where(
          (model) =>
              model.name.toLowerCase().contains(query) ||
              model.id.toLowerCase().contains(query) ||
              model.blurb.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _addProvider() async {
    final provider = CustomProviderConfig(
      id: _nextCustomProviderId(),
      name: '',
      baseUrl: '',
      apiKey: '',
      enabled: true,
    );
    final nextProviders = [...widget.controller.customProviders, provider];
    widget.onSelectedCustomProviderChanged(provider.id);
    setState(() => _lastSyncedProviderId = '');
    _syncControllersFromSelection();
    await widget.controller.saveCustomProviders(nextProviders);
  }

  Future<void> _saveSelectedProvider({bool showSavedState = true}) async {
    final selectedProvider = _selectedCustomProvider;
    if (selectedProvider == null) return;
    final updatedProvider = selectedProvider.copyWith(
      name: _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
    final nextProviders = widget.controller.customProviders
        .map((provider) =>
            provider.id == updatedProvider.id ? updatedProvider : provider)
        .toList();
    await widget.controller.saveCustomProviders(nextProviders);
    if (!mounted || !showSavedState) return;
    setState(() => _justSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _toggleProvider(bool enabled) async {
    final selectedProvider = _selectedCustomProvider;
    if (selectedProvider == null) return;
    final nextProviders = widget.controller.customProviders
        .map(
          (provider) => provider.id == selectedProvider.id
              ? provider.copyWith(enabled: enabled)
              : provider,
        )
        .toList();
    await widget.controller.saveCustomProviders(nextProviders);
  }

  Future<void> _deleteSelectedProvider() async {
    final selectedProvider = _selectedCustomProvider;
    if (selectedProvider == null) return;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete custom provider?'),
            content: const Text(
              'This removes the saved endpoint, key, and fetched models.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) return;
    final remainingProviders = widget.controller.customProviders
        .where((provider) => provider.id != selectedProvider.id)
        .toList();
    await widget.controller.deleteCustomProvider(selectedProvider.id);
    if (!mounted) return;
    widget.onSelectedCustomProviderChanged(
      remainingProviders.isEmpty ? null : remainingProviders.first.id,
    );
    setState(() => _lastSyncedProviderId = '');
    _syncControllersFromSelection();
  }

  Future<void> _fetchModels() async {
    final selectedProvider = _selectedCustomProvider;
    if (selectedProvider == null) return;
    setState(() => _isFetchingModels = true);
    try {
      await _saveSelectedProvider(showSavedState: false);
      await widget.controller
          .fetchModelsFromCustomProvider(selectedProvider.id);
    } finally {
      if (mounted) {
        setState(() => _isFetchingModels = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final customProviders = widget.controller.customProviders;
    final selectedProvider = _selectedCustomProvider;
    final hasSelectedProvider = selectedProvider != null;
    final allModels = hasSelectedProvider
        ? widget.controller.models
            .where(
              (model) =>
                  model.provider == AiProviderType.custom &&
                  model.customProviderId == selectedProvider.id,
            )
            .toList()
        : const <ModelOption>[];
    final filteredModels = _filterModels(allModels);

    return Container(
      decoration: BoxDecoration(
        color: tokens.panelSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selectedProvider?.enabled == true
                        ? tokens.selectedSurface
                        : tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    selectedProvider?.enabled == true
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 18,
                    color: selectedProvider?.enabled == true
                        ? const Color(0xFF2E9E72)
                        : tokens.subtleForeground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedProvider?.normalizedName ?? 'Custom Providers',
                        style: TextStyle(
                          color: tokens.foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedProvider?.normalizedBaseUrl.isNotEmpty == true
                            ? selectedProvider!.normalizedBaseUrl
                            : 'OpenAI-compatible endpoints',
                        style: TextStyle(
                          color: tokens.mutedForeground,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addProvider,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add'),
                  style: _compactActionButtonStyle(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: tokens.mutedBorder, height: 1),
                  const SizedBox(height: 14),
                  if (customProviders.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Add a custom provider to start.',
                              style: TextStyle(
                                color: tokens.subtleForeground,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: _addProvider,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add'),
                              style: _compactActionButtonStyle(),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Text(
                          'Enabled',
                          style: TextStyle(
                            color: tokens.mutedForeground,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: selectedProvider?.enabled ?? false,
                          onChanged: hasSelectedProvider
                              ? (value) => _toggleProvider(value)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: tokens.foreground, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Provider name',
                        hintStyle: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.badge_rounded,
                          size: 18,
                          color: tokens.subtleForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _baseUrlController,
                      keyboardType: TextInputType.url,
                      style: TextStyle(color: tokens.foreground, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://api.example.com/v1',
                        hintStyle: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: tokens.subtleForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,
                      style: TextStyle(color: tokens.foreground, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Enter ${(selectedProvider?.normalizedName ?? 'Custom')} API key',
                        hintStyle: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.key_rounded,
                          size: 18,
                          color: tokens.subtleForeground,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscureKey = !_obscureKey),
                          icon: Icon(
                            _obscureKey
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 18,
                            color: tokens.subtleForeground,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _saveSelectedProvider,
                          icon: Icon(
                            _justSaved
                                ? Icons.check_circle_rounded
                                : Icons.save_rounded,
                            size: 16,
                          ),
                          label: Text(_justSaved ? 'Saved' : 'Save'),
                          style: _compactActionButtonStyle(),
                        ),
                        OutlinedButton.icon(
                          onPressed: _deleteSelectedProvider,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 14),
                          label: const Text('Delete'),
                          style: _compactOutlineActionButtonStyle(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Models',
                          style: TextStyle(
                            color: tokens.foreground,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (allModels.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E9E72)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${allModels.length}',
                              style: const TextStyle(
                                color: Color(0xFF2E9E72),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (_isFetchingModels)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2E9E72),
                            ),
                          )
                        else
                          InkWell(
                            onTap: (selectedProvider?.hasApiKey ?? false)
                                ? _fetchModels
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: (selectedProvider?.hasApiKey ?? false)
                                    ? tokens.accent
                                    : tokens.subtleForeground,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (allModels.isNotEmpty)
                      TextField(
                        controller: _modelSearchController,
                        onChanged: (value) =>
                            setState(() => _modelSearchQuery = value),
                        style:
                            TextStyle(color: tokens.foreground, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search models...',
                          hintStyle: TextStyle(
                            color: tokens.subtleForeground,
                            fontSize: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 16,
                            color: tokens.subtleForeground,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildModelList(
                        tokens: tokens,
                        allModels: allModels,
                        filteredModels: filteredModels,
                        hasKey: selectedProvider?.hasApiKey ?? false,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList({
    required AppThemeTokens tokens,
    required List<ModelOption> allModels,
    required List<ModelOption> filteredModels,
    required bool hasKey,
  }) {
    if (filteredModels.isEmpty && allModels.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'No models match "$_modelSearchQuery"',
            style: TextStyle(color: tokens.subtleForeground, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (allModels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            hasKey ? 'Tap download to fetch models' : 'Add API key first',
            style: TextStyle(color: tokens.subtleForeground, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: filteredModels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final model = filteredModels[index];
        final isSelected =
            model.sameSelectionIdentity(widget.controller.selectedModel);
        return InkWell(
          onTap: () => widget.saveSettings(model: model),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? tokens.selectedSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? tokens.accent.withValues(alpha: 0.4)
                    : tokens.mutedBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: TextStyle(
                          color: tokens.foreground,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (model.blurb.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          model.blurb,
                          style: TextStyle(
                            color: tokens.subtleForeground,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: tokens.accent,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingsSystemPromptSection extends StatelessWidget {
  const SettingsSystemPromptSection({
    super.key,
    required this.systemPromptController,
    required this.saveSettings,
  });

  final TextEditingController systemPromptController;
  final SettingsSaveCallback saveSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsLabel('PROMPT STUDIO'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a tone or add your own reusable system instruction.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PromptTemplateChip(
                    label: 'Coding Assistant',
                    onTap: () => systemPromptController.text =
                        'You are a senior coding assistant. Be concise, accurate, and implementation-focused.',
                  ),
                  _PromptTemplateChip(
                    label: 'Research Analyst',
                    onTap: () => systemPromptController.text =
                        'You are a research analyst. Structure answers clearly and highlight tradeoffs.',
                  ),
                  _PromptTemplateChip(
                    label: 'Concise Mode',
                    onTap: () => systemPromptController.text =
                        'Keep responses short, direct, and high-signal.',
                  ),
                  _PromptTemplateChip(
                    label: 'Vision Helper',
                    onTap: () => systemPromptController.text =
                        'You are an AI assistant specialized in image and multimodal reasoning.',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: systemPromptController,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Add a system prompt for every request',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => saveSettings(),
                      child: const Text('Save'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        systemPromptController.clear();
                        saveSettings();
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsAppearanceSection extends StatelessWidget {
  const SettingsAppearanceSection({
    super.key,
    required this.vm,
    required this.saveSettings,
  });

  final SettingsViewModel vm;
  final SettingsSaveCallback saveSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsLabel('APPEARANCE MODE'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppAppearanceMode.values.map((mode) {
                  return ChoiceChip(
                    selected: vm.appearanceMode == mode,
                    label: Text(appearanceModeLabel(mode)),
                    onSelected: (_) => saveSettings(appearanceMode: mode),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsLabel('DYNAMIC THEME'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Match wallpaper colors',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.foreground,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: vm.dynamicThemeEnabled,
                onChanged: (value) => saveSettings(dynamicThemeEnabled: value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SettingsLabel(
          vm.dynamicThemeEnabled ? 'THEME FAMILY FALLBACK' : 'THEME FAMILY',
        ),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: vm.themes.map((palette) {
              return ThemeSwatchButton(
                palette: palette,
                active: palette.mode == vm.themeMode,
                onTap: () => saveSettings(themeMode: palette.mode),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        _FontPreferenceCard(
          key: const ValueKey('app-font-preference-card'),
          label: 'APP FONT',
          title: 'Workspace typography',
          description: '',
          helperText: '',
          selectedPreset: vm.appFontPreset,
          fontPresets: vm.fontPresets,
          onSelected: (preset) => saveSettings(appFontPreset: preset),
        ),
        const SizedBox(height: 20),
        _FontPreferenceCard(
          key: const ValueKey('chat-font-preference-card'),
          label: 'CHAT FONT',
          title: 'Conversation typography',
          description: '',
          helperText: '',
          selectedPreset: vm.chatFontPreset,
          fontPresets: vm.fontPresets,
          onSelected: (preset) => saveSettings(chatFontPreset: preset),
        ),
        const SizedBox(height: 20),
        const SettingsLabel('CHAT COLOUR'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ChatColorMode.values.map((mode) {
                  return ChoiceChip(
                    selected: vm.chatColorMode == mode,
                    label: Text(chatColorModeLabel(mode)),
                    onSelected: (_) => saveSettings(chatColorMode: mode),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.subtleSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: tokens.mutedBorder),
                ),
                child: Text(
                  vm.chatColorMode == ChatColorMode.theme
                      ? 'Assistant headings, bullets, tables, and highlights follow your current app theme colors.'
                      : 'Assistant formatting switches to a curated five-color chat palette that adapts for light and dark appearance.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.mutedForeground,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsChatDataSection extends StatelessWidget {
  const SettingsChatDataSection({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsLabel('CHAT TOOLS'),
        const SizedBox(height: 12),
        DangerBlock(
          text:
              'Permanently delete your current session history across this device.',
          buttonLabel: 'Clear all chats',
          icon: Icons.delete_outline_rounded,
          onPressed: controller.clearCurrentChat,
        ),
        const SizedBox(height: 20),
        const SettingsLabel('DATA PRIVACY'),
        const SizedBox(height: 12),
        DangerBlock(
          text:
              'Wipe all cached files, models, and personal configuration data.',
          buttonLabel: 'Clear all data',
          icon: Icons.cancel_outlined,
          onPressed: controller.clearAllData,
        ),
      ],
    );
  }
}

class SettingsAboutSection extends StatelessWidget {
  const SettingsAboutSection({
    super.key,
    required this.vm,
  });

  final SettingsViewModel vm;
  static const _developerName = 'Kasif';
  static const _feedbackEmail = 'kasifdevloper@gmail.com';
  static const _licenseName = 'Apache License 2.0';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;
    final feedbackUri = Uri(
      scheme: 'mailto',
      path: _feedbackEmail,
      queryParameters: {'subject': 'Gidar AI Feedback'},
    );
    final bugReportUri = Uri(
      scheme: 'mailto',
      path: _feedbackEmail,
      queryParameters: {'subject': 'Gidar AI Bug Report'},
    );

    Future<void> openUri(Uri uri) async {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(uri);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gidar AI',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: tokens.foreground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Open-source AI workspace for chatting across providers, managing models, previewing generated output, and keeping your workflow in one place.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: tokens.mutedForeground,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _AboutMetaRow(
                label: 'Version',
                value: vm.appVersionLabel,
              ),
              const SizedBox(height: 8),
              _AboutMetaRow(
                label: 'License',
                value: _licenseName,
              ),
              const SizedBox(height: 8),
              _AboutMetaRow(
                label: 'Developer',
                value: _developerName,
              ),
              const SizedBox(height: 8),
              _AboutMetaRow(
                label: 'Enabled providers',
                value: '${vm.enabledProviders.length}',
              ),
              const SizedBox(height: 8),
              _AboutMetaRow(
                label: 'Selected model',
                value: vm.selectedModel?.name ?? 'No model selected',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsLabel('APP SUMMARY'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gidar AI helps users access multiple AI providers from one app, save conversations locally, switch models quickly, and work with generated content through code and HTML tooling.',
                style: TextStyle(
                  color: tokens.mutedForeground,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _AboutTag(label: 'Streaming chat'),
                  _AboutTag(label: 'Multi-provider routing'),
                  _AboutTag(label: 'Saved history'),
                  _AboutTag(label: 'Model management'),
                  _AboutTag(label: 'Attachments'),
                  _AboutTag(label: 'HTML preview'),
                  _AboutTag(label: 'Code sandbox'),
                  _AboutTag(label: 'PDF export'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsLabel('OPEN SOURCE'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This app is open source under Apache License 2.0. You can use, study, modify, and redistribute it. If you share this project or a modified version, keep the required attribution and notice files.',
                style: TextStyle(
                  color: tokens.mutedForeground,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Credit: Created by $_developerName',
                style: TextStyle(
                  color: tokens.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Required attribution is documented in the repository LICENSE and NOTICE files.',
                style: TextStyle(color: tokens.subtleForeground, height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SettingsLabel('FEEDBACK'),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback, bug reports, and support requests are handled by email.',
                style: TextStyle(
                  color: tokens.mutedForeground,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                _feedbackEmail,
                style: TextStyle(
                  color: tokens.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => openUri(feedbackUri),
                    icon: const Icon(Icons.mail_outline_rounded, size: 16),
                    label: const Text('Send Feedback'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => openUri(bugReportUri),
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: const Text('Report Bug'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.mutedForeground,
                      side: BorderSide(color: tokens.mutedBorder),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutMetaRow extends StatelessWidget {
  const _AboutMetaRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: TextStyle(
              color: tokens.subtleForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: tokens.foreground,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutTag extends StatelessWidget {
  const _AboutTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.chipSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsNavCard extends StatelessWidget {
  const _SettingsNavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SettingsBlock(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tokens.chipSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tokens.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.mutedForeground,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: tokens.subtleForeground,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tokens.accent, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tokens.mutedForeground,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: tokens.foreground,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSelectorChip extends StatelessWidget {
  const _ProviderSelectorChip({
    required this.provider,
    this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AiProviderType provider;
  final String? label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? tokens.selectedSurface : tokens.panelSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? tokens.accent : tokens.mutedBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 15,
              color:
                  enabled ? const Color(0xFF2E9E72) : tokens.subtleForeground,
            ),
            const SizedBox(width: 6),
            Text(
              label ?? providerLabel(provider),
              style: TextStyle(
                color: selected ? tokens.foreground : tokens.mutedForeground,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderDetailCard extends StatefulWidget {
  const _ProviderDetailCard({
    required this.provider,
    required this.vm,
    required this.controller,
    required this.actions,
    required this.saveSettings,
    required this.keyController,
    required this.customNameController,
    required this.customBaseUrlController,
    this.onDeleteCustomProvider,
    required this.obscureApiKey,
    required this.onToggleObscure,
  });

  final AiProviderType provider;
  final SettingsViewModel vm;
  final AppController controller;
  final SettingsActions actions;
  final SettingsSaveCallback saveSettings;
  final TextEditingController keyController;
  final TextEditingController customNameController;
  final TextEditingController customBaseUrlController;
  final Future<void> Function()? onDeleteCustomProvider;
  final bool obscureApiKey;
  final VoidCallback onToggleObscure;

  @override
  State<_ProviderDetailCard> createState() => _ProviderDetailCardState();
}

class _ProviderDetailCardState extends State<_ProviderDetailCard> {
  bool _obscureKey = true;
  bool _justSaved = false;
  bool _isFetchingModels = false;
  final TextEditingController _modelSearchController = TextEditingController();
  String _modelSearchQuery = '';

  @override
  void dispose() {
    _modelSearchController.dispose();
    super.dispose();
  }

  ProviderKeys _draftProviderKeys() {
    final key = widget.keyController.text.trim();
    return switch (widget.provider) {
      AiProviderType.openRouter =>
        widget.vm.providerKeys.copyWith(openRouter: key),
      AiProviderType.groq => widget.vm.providerKeys.copyWith(groq: key),
      AiProviderType.gemini => widget.vm.providerKeys.copyWith(gemini: key),
      AiProviderType.cerebras => widget.vm.providerKeys.copyWith(cerebras: key),
      AiProviderType.zAi => widget.vm.providerKeys.copyWith(zAi: key),
      AiProviderType.mistral => widget.vm.providerKeys.copyWith(mistral: key),
      AiProviderType.sambanova =>
        widget.vm.providerKeys.copyWith(sambanova: key),
      AiProviderType.custom => widget.vm.providerKeys.copyWith(custom: key),
    };
  }

  CustomProviderConfig? _draftCustomProvider() {
    return widget.provider == AiProviderType.custom
        ? widget.vm.customProvider.copyWith(
            name: widget.customNameController.text.trim(),
            baseUrl: widget.customBaseUrlController.text.trim(),
          )
        : null;
  }

  void _saveKey() {
    final updatedKeys = _draftProviderKeys();
    final updatedCustomProvider = _draftCustomProvider();
    widget.saveSettings(
      providerKeys: updatedKeys,
      customProvider: updatedCustomProvider,
    );
    setState(() => _justSaved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justSaved = false);
    });
  }

  Future<void> _fetchModels() async {
    setState(() => _isFetchingModels = true);
    try {
      await widget.saveSettings(
        providerKeys: _draftProviderKeys(),
        customProvider: _draftCustomProvider(),
      );
      await widget.controller.fetchModelsFromProvider(
        widget.provider,
        apiKey: widget.keyController.text.trim(),
      );
    } catch (_) {}
    if (mounted) setState(() => _isFetchingModels = false);
  }

  Future<void> _confirmDeleteCustomProvider() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete custom provider?'),
            content: const Text(
              'This removes the saved endpoint, key, and fetched models.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete || widget.onDeleteCustomProvider == null) return;
    await widget.onDeleteCustomProvider!();
  }

  List<ModelOption> _filterModels(List<ModelOption> models) {
    if (_modelSearchQuery.isEmpty) return models;
    final q = _modelSearchQuery.toLowerCase();
    return models
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.id.toLowerCase().contains(q) ||
            m.blurb.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final provider = widget.provider;
    final label = provider == AiProviderType.custom
        ? widget.vm.customProvider.normalizedName
        : providerLabel(provider);
    final note = provider == AiProviderType.custom &&
            widget.vm.customProvider.normalizedBaseUrl.isNotEmpty
        ? widget.vm.customProvider.normalizedBaseUrl
        : providerNote(provider);
    final apiKeyUrl = providerApiKeyUrl(provider);
    final isCustomProvider = provider == AiProviderType.custom;
    final enabled = widget.vm.enabledProviders.contains(provider);
    final hasKey = widget.keyController.text.trim().isNotEmpty;
    final allModels = widget.vm.modelsFor(provider);
    final filteredModels = _filterModels(allModels);

    return Container(
      decoration: BoxDecoration(
        color: tokens.panelSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasKey && _justSaved
              ? const Color(0xFF2E9E72).withValues(alpha: 0.5)
              : tokens.mutedBorder,
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: enabled
                          ? tokens.selectedSurface
                          : tokens.elevatedSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      enabled
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: enabled
                          ? const Color(0xFF2E9E72)
                          : tokens.subtleForeground,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: tokens.foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: TextStyle(
                            color: tokens.mutedForeground,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (hasKey)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E9E72).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${allModels.length} models',
                        style: const TextStyle(
                          color: Color(0xFF2E9E72),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.push_pin_rounded,
                    color: tokens.accent,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                    color: tokens.mutedBorder,
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  // Enable toggle
                  Row(
                    children: [
                      Text(
                        'Enabled',
                        style: TextStyle(
                          color: tokens.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: enabled,
                        onChanged: (val) {
                          final providers = widget.actions.toggleProvider(
                            widget.vm.enabledProviders,
                            provider,
                            val,
                          );
                          widget.saveSettings(enabledProviders: providers);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isCustomProvider) ...[
                    TextField(
                      controller: widget.customNameController,
                      style: TextStyle(color: tokens.foreground, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Provider name',
                        hintStyle: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.badge_rounded,
                          size: 18,
                          color: tokens.subtleForeground,
                        ),
                        filled: true,
                        fillColor: tokens.searchSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tokens.mutedBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tokens.mutedBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tokens.accent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: widget.customBaseUrlController,
                      keyboardType: TextInputType.url,
                      style: TextStyle(color: tokens.foreground, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://api.example.com/v1',
                        hintStyle: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.link_rounded,
                          size: 18,
                          color: tokens.subtleForeground,
                        ),
                        filled: true,
                        fillColor: tokens.searchSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tokens.mutedBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tokens.mutedBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: tokens.accent),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // API Key input
                  TextField(
                    controller: widget.keyController,
                    obscureText: _obscureKey,
                    style: TextStyle(color: tokens.foreground, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter $label API key',
                      hintStyle: TextStyle(
                        color: tokens.subtleForeground,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.key_rounded,
                        size: 18,
                        color: tokens.subtleForeground,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 18,
                          color: tokens.subtleForeground,
                        ),
                      ),
                      filled: true,
                      fillColor: tokens.searchSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.mutedBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.mutedBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: tokens.accent),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Save Key + Get Key row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: _saveKey,
                        icon: Icon(
                          _justSaved
                              ? Icons.check_circle_rounded
                              : Icons.save_rounded,
                          size: 16,
                        ),
                        label: Text(_justSaved ? 'Saved' : 'Save Key'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _justSaved
                              ? const Color(0xFF2E9E72)
                              : tokens.accent,
                          foregroundColor:
                              _justSaved ? Colors.white : tokens.onAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (isCustomProvider &&
                          widget.onDeleteCustomProvider != null)
                        OutlinedButton.icon(
                          onPressed: _confirmDeleteCustomProvider,
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 14),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.mutedForeground,
                            side: BorderSide(color: tokens.mutedBorder),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (!isCustomProvider && apiKeyUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(apiKeyUrl);
                            try {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } catch (_) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Get Key'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tokens.mutedForeground,
                            side: BorderSide(color: tokens.mutedBorder),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      if (_justSaved)
                        const Text(
                          '● Key Saved',
                          style: TextStyle(
                            color: Color(0xFF2E9E72),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Models section
                  Row(
                    children: [
                      Text(
                        'Models',
                        style: TextStyle(
                          color: tokens.foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (allModels.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2E9E72).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${allModels.length}',
                            style: const TextStyle(
                              color: Color(0xFF2E9E72),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (_isFetchingModels)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF2E9E72),
                          ),
                        )
                      else
                        InkWell(
                          onTap: hasKey ? _fetchModels : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: hasKey
                                  ? tokens.accent
                                  : tokens.subtleForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Model search
                  if (allModels.isNotEmpty)
                    TextField(
                      controller: _modelSearchController,
                      onChanged: (v) => setState(() => _modelSearchQuery = v),
                      style: TextStyle(color: tokens.foreground, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search models...',
                        hintStyle: TextStyle(
                          color: tokens.subtleForeground,
                          fontSize: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: tokens.subtleForeground,
                        ),
                        filled: true,
                        fillColor: tokens.searchSurface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _buildModelList(
                      tokens: tokens,
                      allModels: allModels,
                      filteredModels: filteredModels,
                      hasKey: hasKey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelList({
    required AppThemeTokens tokens,
    required List<ModelOption> allModels,
    required List<ModelOption> filteredModels,
    required bool hasKey,
  }) {
    if (filteredModels.isEmpty && allModels.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'No models match "$_modelSearchQuery"',
            style: TextStyle(color: tokens.subtleForeground, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (allModels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            hasKey ? 'Tap download to fetch models' : 'Add API key first',
            style: TextStyle(color: tokens.subtleForeground, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: filteredModels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final model = filteredModels[index];
        final isSelected = model.sameSelectionIdentity(widget.vm.selectedModel);
        final isFree = model.blurb.toLowerCase().contains('free');
        return InkWell(
          onTap: () => widget.saveSettings(model: model),
          onLongPress: () => _showModelDetails(context, model),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? tokens.selectedSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? tokens.accent.withValues(alpha: 0.4)
                    : tokens.mutedBorder.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.name,
                              style: TextStyle(
                                color: tokens.foreground,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFree) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E9E72)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'FREE',
                                style: TextStyle(
                                  color: Color(0xFF2E9E72),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          if (model.inputPrice != null &&
                              model.outputPrice != null &&
                              !isFree) ...[
                            const SizedBox(width: 6),
                            _ModelPricingBadge(
                              inputPrice: model.inputPrice!,
                              outputPrice: model.outputPrice!,
                            ),
                          ],
                          if (model.supportsVision) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.visibility_rounded,
                              size: 14,
                              color: tokens.accent,
                            ),
                          ],
                        ],
                      ),
                      if (model.blurb.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          model.blurb,
                          style: TextStyle(
                            color: tokens.subtleForeground,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: tokens.accent,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showModelDetails(BuildContext context, ModelOption model) {
    final tokens = context.appThemeTokens;
    String showValue(String? value) =>
        value == null || value.trim().isEmpty ? 'Not published' : value;
    String showInt(int? value) => value == null ? 'Not published' : '$value';
    final visionLabel = switch (model.visionSupport) {
      ModelVisionSupport.supported => 'Supported',
      ModelVisionSupport.unsupported => 'Unsupported',
      ModelVisionSupport.unknown => 'Unknown',
    };

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.modalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: TextStyle(
                    color: tokens.foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  model.id,
                  style: TextStyle(
                    color: tokens.subtleForeground,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                if ((model.description ?? model.blurb).trim().isNotEmpty)
                  Text(
                    model.description ?? model.blurb,
                    style: TextStyle(
                      color: tokens.mutedForeground,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 16),
                Text('Vision: $visionLabel',
                    style: TextStyle(color: tokens.foreground)),
                const SizedBox(height: 8),
                Text('Context window: ${showInt(model.contextWindow)}',
                    style: TextStyle(color: tokens.foreground)),
                const SizedBox(height: 8),
                Text('Max output tokens: ${showInt(model.maxOutputTokens)}',
                    style: TextStyle(color: tokens.foreground)),
                const SizedBox(height: 8),
                Text('Input price: ${showValue(model.inputPrice)}',
                    style: TextStyle(color: tokens.foreground)),
                const SizedBox(height: 8),
                Text('Output price: ${showValue(model.outputPrice)}',
                    style: TextStyle(color: tokens.foreground)),
                const SizedBox(height: 8),
                Text(
                  'Streaming: ${model.supportsStreaming ? 'Supported' : 'Unsupported'}',
                  style: TextStyle(color: tokens.foreground),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelPricingBadge extends StatelessWidget {
  const _ModelPricingBadge({
    required this.inputPrice,
    required this.outputPrice,
  });

  final String inputPrice;
  final String outputPrice;

  String _formatPrice(String price) {
    final value = double.tryParse(price);
    if (value == null) return price;
    if (value == 0) return 'Free';
    final perMillion = value * 1000000;
    if (perMillion >= 1) return '\$${perMillion.toStringAsFixed(1)}/M';
    return '\$${perMillion.toStringAsFixed(2)}/M';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC107).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${_formatPrice(inputPrice)} → ${_formatPrice(outputPrice)}',
        style: const TextStyle(
          color: Color(0xFFFFC107),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FontPreferenceCard extends StatelessWidget {
  const _FontPreferenceCard({
    super.key,
    required this.label,
    required this.title,
    required this.description,
    required this.helperText,
    required this.selectedPreset,
    required this.fontPresets,
    required this.onSelected,
  });

  final String label;
  final String title;
  final String description;
  final String helperText;
  final AppFontPreset selectedPreset;
  final List<AppFontPreset> fontPresets;
  final ValueChanged<AppFontPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;
    final featuredPresets = _featuredPresetsFor(fontPresets);
    final libraryPresets = fontPresets
        .where((preset) => !featuredPresets.contains(preset))
        .toList();
    final selectedTags = appFontPresetTags(selectedPreset);
    final previewStyle = resolveFontPresetTextStyle(
      selectedPreset,
      theme.textTheme.bodyLarge?.copyWith(
            color: tokens.foreground,
            fontSize: 14.5,
            height: 1.45,
          ) ??
          TextStyle(
            color: tokens.foreground,
            fontSize: 14.5,
            height: 1.45,
          ),
    );
    final previewTitleStyle = resolveFontPresetTextStyle(
      selectedPreset,
      theme.textTheme.titleMedium?.copyWith(
            color: tokens.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ) ??
          TextStyle(
            color: tokens.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsLabel(label),
        const SizedBox(height: 12),
        SettingsBlock(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.foreground,
                ),
              ),
              const SizedBox(height: 14),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.subtleSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.shadow.withValues(alpha: 0.16),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current pick',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: tokens.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                appFontPresetLabel(selectedPreset),
                                style: previewTitleStyle,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                appFontPreviewText(selectedPreset),
                                style: previewStyle,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Live',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: tokens.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: selectedTags
                          .take(5)
                          .map((tag) => _FontTagChip(label: _tagLabel(tag)))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      appFontPresetNote(selectedPreset),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.subtleForeground,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (featuredPresets.isNotEmpty) ...[
                _FontRail(
                  title: 'Best picks',
                  subtitle: '',
                  presets: featuredPresets,
                  selectedPreset: selectedPreset,
                  onSelected: onSelected,
                ),
                const SizedBox(height: 16),
              ],
              if (libraryPresets.isNotEmpty) ...[
                _FontRail(
                  title: 'More fonts',
                  subtitle: '',
                  presets: libraryPresets,
                  selectedPreset: selectedPreset,
                  onSelected: onSelected,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<AppFontPreset> _featuredPresetsFor(List<AppFontPreset> presets) {
    const featuredOrder = [
      AppFontPreset.notoSansDevanagari,
      AppFontPreset.tiroDevanagariHindi,
      AppFontPreset.martelSans,
      AppFontPreset.roboto,
      AppFontPreset.manrope,
      AppFontPreset.urbanist,
      AppFontPreset.plusJakartaSans,
      AppFontPreset.sora,
      AppFontPreset.hind,
      AppFontPreset.mukta,
      AppFontPreset.notoSerifDevanagari,
      AppFontPreset.kalam,
    ];
    final ordered = <AppFontPreset>[
      ...featuredOrder.where(presets.contains),
      ...presets.where((preset) => !featuredOrder.contains(preset)),
    ];
    return ordered.take(4).toList();
  }
}

class _FontRail extends StatelessWidget {
  const _FontRail({
    required this.title,
    required this.subtitle,
    required this.presets,
    required this.selectedPreset,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final List<AppFontPreset> presets;
  final AppFontPreset selectedPreset;
  final ValueChanged<AppFontPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: tokens.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((preset) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 272,
                  child: _FontOptionCard(
                    preset: preset,
                    selected: selectedPreset == preset,
                    onTap: () => onSelected(preset),
                    compact: true,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _FontOptionCard extends StatelessWidget {
  const _FontOptionCard({
    required this.preset,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final AppFontPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;
    final titleStyle = resolveFontPresetTextStyle(
      preset,
      theme.textTheme.titleMedium?.copyWith(
            color: tokens.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ) ??
          TextStyle(
            color: tokens.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
    );
    final previewStyle = resolveFontPresetTextStyle(
      preset,
      theme.textTheme.bodyMedium?.copyWith(
            color: tokens.foreground,
            fontSize: 14,
            height: 1.42,
          ) ??
          TextStyle(
            color: tokens.foreground,
            fontSize: 14,
            height: 1.42,
          ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? tokens.selectedSurface : tokens.panelSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? tokens.accent : tokens.mutedBorder,
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appFontPresetLabel(preset),
                    style: titleStyle,
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: tokens.accent,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: appFontPresetTags(preset)
                  .take(compact ? 3 : 4)
                  .map((tag) => _FontTagChip(label: _tagLabel(tag)))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Text(
              appFontPreviewText(preset),
              style: previewStyle,
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text(
                appFontPresetNote(preset),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tokens.mutedForeground,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FontTagChip extends StatelessWidget {
  const _FontTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.chipSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: tokens.mutedForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _tagLabel(String tag) {
  return switch (tag) {
    'ui' => 'UI',
    'pro' => 'Pro',
    _ => '${tag[0].toUpperCase()}${tag.substring(1)}',
  };
}

class _PromptTemplateChip extends StatelessWidget {
  const _PromptTemplateChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}

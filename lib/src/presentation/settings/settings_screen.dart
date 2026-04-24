import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../components/app_ui.dart';
import 'settings_actions.dart';
import 'settings_sections.dart';
import 'settings_view_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.apiKeyController,
    required this.systemPromptController,
    required this.obscureApiKey,
    required this.onToggleObscure,
    required this.onOpenSidebar,
    required this.section,
    required this.onOpenSection,
  });

  final TextEditingController apiKeyController;
  final TextEditingController systemPromptController;
  final bool obscureApiKey;
  final VoidCallback onToggleObscure;
  final VoidCallback onOpenSidebar;
  final SettingsSection section;
  final ValueChanged<SettingsSection> onOpenSection;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _groqKeyController;
  late final TextEditingController _geminiKeyController;
  late final TextEditingController _cerebrasKeyController;
  late final TextEditingController _zAiKeyController;
  late final TextEditingController _mistralKeyController;
  late final TextEditingController _sambanovaKeyController;
  late final TextEditingController _customKeyController;
  late final TextEditingController _customProviderNameController;
  late final TextEditingController _customProviderBaseUrlController;
  String _lastGroqKey = '';
  String _lastGeminiKey = '';
  String _lastCerebrasKey = '';
  String _lastZAiKey = '';
  String _lastMistralKey = '';
  String _lastSambanovaKey = '';
  String _lastCustomKey = '';
  String _lastCustomProviderName = '';
  String _lastCustomProviderBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _groqKeyController = TextEditingController();
    _geminiKeyController = TextEditingController();
    _cerebrasKeyController = TextEditingController();
    _zAiKeyController = TextEditingController();
    _mistralKeyController = TextEditingController();
    _sambanovaKeyController = TextEditingController();
    _customKeyController = TextEditingController();
    _customProviderNameController = TextEditingController();
    _customProviderBaseUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _groqKeyController.dispose();
    _geminiKeyController.dispose();
    _cerebrasKeyController.dispose();
    _zAiKeyController.dispose();
    _mistralKeyController.dispose();
    _sambanovaKeyController.dispose();
    _customKeyController.dispose();
    _customProviderNameController.dispose();
    _customProviderBaseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.watch(settingsViewModelProvider);
    final controller = ref.read(appControllerProvider);
    final actions = ref.read(settingsActionsProvider);
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 980;
    final isOverview = widget.section == SettingsSection.overview;
    final showLeading = !isDesktop || !isOverview;
    final leadingIcon =
        isOverview ? Icons.menu_rounded : Icons.arrow_back_ios_new_rounded;
    final sectionTitle = widget.section == SettingsSection.overview
        ? 'Settings'
        : _sectionTitle(widget.section);
    final sectionSubtitle = widget.section == SettingsSection.overview
        ? ''
        : _sectionSubtitle(widget.section);

    _syncProviderControllers(vm);

    Future<void> saveSettings({
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
    }) {
      return actions.save(
        vm: vm,
        form: _buildFormSnapshot(),
        model: model ?? vm.selectedModel,
        themeMode: themeMode ?? vm.themeMode,
        appearanceMode: appearanceMode ?? vm.appearanceMode,
        dynamicThemeEnabled: dynamicThemeEnabled ?? vm.dynamicThemeEnabled,
        providerKeys: providerKeys,
        routingMode: routingMode ?? vm.routingMode,
        enabledProviders: enabledProviders ?? vm.enabledProviders,
        uiDensityMode: uiDensityMode ?? vm.uiDensityMode,
        appFontPreset: appFontPreset ?? vm.appFontPreset,
        chatFontPreset: chatFontPreset ?? vm.chatFontPreset,
        chatColorMode: chatColorMode ?? vm.chatColorMode,
      );
    }

    final sectionContent = switch (widget.section) {
      SettingsSection.overview => SettingsOverviewSection(
          vm: vm,
          theme: theme,
          onOpenSection: widget.onOpenSection,
        ),
      SettingsSection.providers => SettingsProvidersSection(
          vm: vm,
          controller: controller,
          actions: actions,
          saveSettings: saveSettings,
          apiKeyController: widget.apiKeyController,
          groqKeyController: _groqKeyController,
          geminiKeyController: _geminiKeyController,
          cerebrasKeyController: _cerebrasKeyController,
          zAiKeyController: _zAiKeyController,
          mistralKeyController: _mistralKeyController,
          sambanovaKeyController: _sambanovaKeyController,
          customKeyController: _customKeyController,
          customProviderNameController: _customProviderNameController,
          customProviderBaseUrlController: _customProviderBaseUrlController,
          obscureApiKey: widget.obscureApiKey,
          onToggleObscure: widget.onToggleObscure,
        ),
      SettingsSection.models => SettingsOverviewSection(
          vm: vm,
          theme: theme,
          onOpenSection: widget.onOpenSection,
        ),
      SettingsSection.systemPrompt => SettingsSystemPromptSection(
          systemPromptController: widget.systemPromptController,
          saveSettings: saveSettings,
        ),
      SettingsSection.appearance => SettingsAppearanceSection(
          vm: vm,
          saveSettings: saveSettings,
        ),
      SettingsSection.chatData =>
        SettingsChatDataSection(controller: controller),
      SettingsSection.about => SettingsAboutSection(vm: vm),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Column(
        children: [
          GidarTopBar(
            title: 'Gidar AI',
            leadingIcon: leadingIcon,
            showLeading: showLeading,
            onLeadingTap: isOverview
                ? widget.onOpenSidebar
                : () => widget.onOpenSection(SettingsSection.overview),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              sectionTitle,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (sectionSubtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                sectionSubtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(
            child: widget.section == SettingsSection.providers
                ? sectionContent
                : ListView(
                    padding: const EdgeInsets.only(bottom: 142),
                    children: [
                      sectionContent,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _syncProviderControllers(SettingsViewModel vm) {
    if (_lastGroqKey != vm.providerKeys.groq) {
      _groqKeyController.text = vm.providerKeys.groq;
      _lastGroqKey = vm.providerKeys.groq;
    }
    if (_lastGeminiKey != vm.providerKeys.gemini) {
      _geminiKeyController.text = vm.providerKeys.gemini;
      _lastGeminiKey = vm.providerKeys.gemini;
    }
    if (_lastCerebrasKey != vm.providerKeys.cerebras) {
      _cerebrasKeyController.text = vm.providerKeys.cerebras;
      _lastCerebrasKey = vm.providerKeys.cerebras;
    }
    if (_lastZAiKey != vm.providerKeys.zAi) {
      _zAiKeyController.text = vm.providerKeys.zAi;
      _lastZAiKey = vm.providerKeys.zAi;
    }
    if (_lastMistralKey != vm.providerKeys.mistral) {
      _mistralKeyController.text = vm.providerKeys.mistral;
      _lastMistralKey = vm.providerKeys.mistral;
    }
    if (_lastSambanovaKey != vm.providerKeys.sambanova) {
      _sambanovaKeyController.text = vm.providerKeys.sambanova;
      _lastSambanovaKey = vm.providerKeys.sambanova;
    }
    if (_lastCustomKey != vm.providerKeys.custom) {
      _customKeyController.text = vm.providerKeys.custom;
      _lastCustomKey = vm.providerKeys.custom;
    }
    if (_lastCustomProviderName != vm.customProvider.name) {
      _customProviderNameController.text = vm.customProvider.name;
      _lastCustomProviderName = vm.customProvider.name;
    }
    if (_lastCustomProviderBaseUrl != vm.customProvider.normalizedBaseUrl) {
      _customProviderBaseUrlController.text =
          vm.customProvider.normalizedBaseUrl;
      _lastCustomProviderBaseUrl = vm.customProvider.normalizedBaseUrl;
    }
  }

  SettingsFormSnapshot _buildFormSnapshot() {
    return SettingsFormSnapshot(
      apiKey: widget.apiKeyController.text,
      groqKey: _groqKeyController.text,
      geminiKey: _geminiKeyController.text,
      cerebrasKey: _cerebrasKeyController.text,
      zAiKey: _zAiKeyController.text,
      mistralKey: _mistralKeyController.text,
      sambanovaKey: _sambanovaKeyController.text,
      customKey: _customKeyController.text,
      customProviderName: _customProviderNameController.text,
      customProviderBaseUrl: _customProviderBaseUrlController.text,
      systemPrompt: widget.systemPromptController.text,
    );
  }

  String _sectionTitle(SettingsSection section) {
    return switch (section) {
      SettingsSection.overview => 'Settings',
      SettingsSection.providers => 'Providers',
      SettingsSection.models => 'Models',
      SettingsSection.systemPrompt => 'System Prompt',
      SettingsSection.appearance => 'Appearance',
      SettingsSection.chatData => 'Chat & Data',
      SettingsSection.about => 'About',
    };
  }

  String _sectionSubtitle(SettingsSection section) {
    return switch (section) {
      SettingsSection.overview => '',
      SettingsSection.providers => '',
      SettingsSection.models =>
        'Control routing mode, grouped models, and current selection.',
      SettingsSection.systemPrompt => '',
      SettingsSection.appearance => '',
      SettingsSection.chatData =>
        'Clean chats, clear data, and manage destructive actions safely.',
      SettingsSection.about =>
        'View the app summary, open-source credit, and feedback details.',
    };
  }
}

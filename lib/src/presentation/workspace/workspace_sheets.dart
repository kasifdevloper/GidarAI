import 'package:flutter/material.dart';

import '../../core/models/app_descriptors.dart';
import '../../core/models/app_models.dart';
import '../../core/services/app_controller.dart';
import '../../core/theme/app_theme.dart';

class WorkspaceProviderPickerSheet extends StatelessWidget {
  const WorkspaceProviderPickerSheet({
    super.key,
    required this.controller,
    required this.onProviderSelected,
  });

  final AppController controller;
  final void Function(AiProviderType?, String?) onProviderSelected;

  @override
  Widget build(BuildContext context) {
    final enabledProviders = controller.enabledProviders;
    final currentProvider = controller.selectedProvider;
    final currentCustomProviderId = controller.selectedCustomProviderId;
    final tokens = context.appThemeTokens;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Provider',
              style: TextStyle(
                color: tokens.foreground,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a provider to filter models, or show all providers together.',
              style: TextStyle(color: tokens.mutedForeground, height: 1.4),
            ),
            const SizedBox(height: 16),
            _ProviderTile(
              label: 'All Providers',
              icon: Icons.auto_awesome_rounded,
              isActive: currentProvider == null,
              onTap: () {
                onProviderSelected(null, null);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            ...enabledProviders
                .where((provider) => provider != AiProviderType.custom)
                .map((provider) {
              final modelCount =
                  controller.models.where((m) => m.provider == provider).length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProviderTile(
                  label: providerLabel(provider),
                  icon: Icons.hub_rounded,
                  isActive: currentProvider == provider,
                  modelCount: modelCount,
                  onTap: () {
                    onProviderSelected(provider, null);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            ...controller.customProviders
                .where((provider) => provider.hasName)
                .map((provider) {
              final modelCount = controller.models
                  .where(
                    (model) =>
                        model.provider == AiProviderType.custom &&
                        model.customProviderId == provider.id,
                  )
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ProviderTile(
                  label: provider.normalizedName,
                  icon: Icons.hub_rounded,
                  isActive: currentProvider == AiProviderType.custom &&
                      currentCustomProviderId == provider.id,
                  modelCount: modelCount,
                  onTap: () {
                    onProviderSelected(AiProviderType.custom, provider.id);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.modelCount,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final int? modelCount;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? tokens.selectedSurface : tokens.panelSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? tokens.accent.withValues(alpha: 0.4)
                : tokens.mutedBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isActive ? tokens.selectedSurface : tokens.elevatedSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isActive ? tokens.accent : tokens.mutedForeground,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: tokens.foreground,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (modelCount != null)
              Text(
                '$modelCount models',
                style: TextStyle(
                  color: tokens.subtleForeground,
                  fontSize: 12,
                ),
              ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle_rounded,
                color: tokens.accent,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WorkspaceCommandSheet extends StatelessWidget {
  const WorkspaceCommandSheet({
    super.key,
    required this.commands,
    required this.onSelected,
  });

  final List<String> commands;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(18),
        children: commands.map((command) {
          return ListTile(
            title: Text(command, style: TextStyle(color: tokens.foreground)),
            subtitle: Text(
              switch (command) {
                '/new' => 'Start a fresh chat',
                '/clear' => 'Delete the current chat',
                '/model' => 'Open the model picker',
                '/settings' => 'Open settings',
                '/copy' => 'Copy the latest AI message',
                '/export' => 'Export the current conversation',
                '/help' => 'Show the command list',
                _ => '',
              },
              style: TextStyle(color: tokens.mutedForeground),
            ),
            onTap: () {
              Navigator.pop(context);
              onSelected(command);
            },
          );
        }).toList(),
      ),
    );
  }
}

class WorkspaceModelPickerSheet extends StatefulWidget {
  const WorkspaceModelPickerSheet({
    super.key,
    required this.controller,
    this.initialScrollOffset = 0,
    this.onScrollOffsetChanged,
  });

  final AppController controller;
  final double initialScrollOffset;
  final ValueChanged<double>? onScrollOffsetChanged;

  @override
  State<WorkspaceModelPickerSheet> createState() =>
      _WorkspaceModelPickerSheetState();
}

class _WorkspaceModelPickerSheetState extends State<WorkspaceModelPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset:
          widget.initialScrollOffset < 0 ? 0 : widget.initialScrollOffset,
    )..addListener(_handleScrollOffsetChanged);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScrollOffsetChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScrollOffsetChanged() {
    widget.onScrollOffsetChanged?.call(_scrollController.offset);
  }

  List<ModelOption> _filterModels(List<ModelOption> models) {
    if (_searchQuery.isEmpty) return models;
    final query = _searchQuery.toLowerCase();
    return models.where((model) {
      return model.name.toLowerCase().contains(query) ||
          model.id.toLowerCase().contains(query) ||
          model.blurb.toLowerCase().contains(query);
    }).toList();
  }

  List<_ModelPickerEntry> _buildEntries(List<AiProviderType> providers) {
    final entries = <_ModelPickerEntry>[];
    for (final provider in providers) {
      if (provider == AiProviderType.custom) {
        final selectedCustomProviderId =
            widget.controller.selectedCustomProviderId;
        if ((selectedCustomProviderId ?? '').trim().isNotEmpty) {
          final label = widget.controller.customProviders
              .where((customProvider) =>
                  customProvider.id == selectedCustomProviderId)
              .map((customProvider) => customProvider.normalizedName)
              .fold<String?>(
                null,
                (current, name) => current ?? name,
              );
          final models = _filterModels(
            widget.controller.models
                .where(
                  (model) =>
                      model.provider == AiProviderType.custom &&
                      model.customProviderId == selectedCustomProviderId,
                )
                .toList(),
          );
          if (models.isNotEmpty) {
            entries.add(
              _ProviderHeaderEntry(label ?? providerLabel(provider)),
            );
            entries.addAll(models.map(_ModelItemEntry.new));
          }
          continue;
        }

        for (final customProvider in widget.controller.customProviders) {
          final models = _filterModels(
            widget.controller.models
                .where(
                  (model) =>
                      model.provider == AiProviderType.custom &&
                      model.customProviderId == customProvider.id,
                )
                .toList(),
          );
          if (models.isEmpty) continue;
          entries.add(_ProviderHeaderEntry(customProvider.normalizedName));
          entries.addAll(models.map(_ModelItemEntry.new));
        }
        continue;
      }
      final models = _filterModels(
        widget.controller.models
            .where((model) => model.provider == provider)
            .toList(),
      );
      if (models.isEmpty) continue;
      entries.add(_ProviderHeaderEntry(providerLabel(provider)));
      entries.addAll(models.map(_ModelItemEntry.new));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final selectedProvider = widget.controller.selectedProvider;
    final providers = selectedProvider != null
        ? [selectedProvider]
        : AiProviderType.values
            .where(
              (provider) => widget.controller.models.any(
                (model) => model.provider == provider,
              ),
            )
            .toList();
    final entries = _buildEntries(providers);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Model Selector',
                    style: TextStyle(
                      color: tokens.foreground,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedProvider != null
                        ? 'Showing ${widget.controller.selectedProviderLabel} models.'
                        : 'Pick a model from all providers.',
                    style:
                        TextStyle(color: tokens.mutedForeground, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: TextStyle(color: tokens.foreground, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search models...',
                      hintStyle: TextStyle(
                          color: tokens.subtleForeground, fontSize: 14),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: tokens.subtleForeground,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: tokens.subtleForeground,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: tokens.searchSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return switch (entry) {
                    _ProviderHeaderEntry() => _ModelProviderSectionHeader(
                        label: entry.label,
                      ),
                    _ModelItemEntry() => _ModelPickerTile(
                        model: entry.model,
                        controller: widget.controller,
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

sealed class _ModelPickerEntry {
  const _ModelPickerEntry();
}

class _ProviderHeaderEntry extends _ModelPickerEntry {
  const _ProviderHeaderEntry(this.label);

  final String label;
}

class _ModelItemEntry extends _ModelPickerEntry {
  const _ModelItemEntry(this.model);

  final ModelOption model;
}

class _ModelProviderSectionHeader extends StatelessWidget {
  const _ModelProviderSectionHeader({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.panelSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tokens.foreground,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ModelPickerTile extends StatelessWidget {
  const _ModelPickerTile({
    required this.model,
    required this.controller,
  });

  final ModelOption model;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    final active = model.sameSelectionIdentity(controller.selectedModel);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () async {
          final navigator = Navigator.of(context);
          await controller.saveSettings(
            apiKey: controller.apiKey,
            systemPrompt: controller.systemPrompt,
            model: model,
            themeMode: controller.themeMode,
            appearanceMode: controller.appearanceMode,
          );
          navigator.pop();
        },
        onLongPress: () => _showModelDetailsSheet(context, model),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? tokens.selectedSurface : tokens.elevatedSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? tokens.accent : tokens.mutedBorder,
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
                        Expanded(
                          child: Text(
                            model.name,
                            style: TextStyle(
                              color: tokens.foreground,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (model.inputPrice != null &&
                            model.outputPrice != null)
                          _PricingBadge(
                            inputPrice: model.inputPrice!,
                            outputPrice: model.outputPrice!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.blurb,
                      style: TextStyle(
                        color: tokens.mutedForeground,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (model.supportsVision)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.visibility_rounded,
                    color: tokens.accent,
                    size: 18,
                  ),
                ),
              if (active)
                Icon(
                  Icons.check_circle_rounded,
                  color: tokens.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingBadge extends StatelessWidget {
  const _PricingBadge({
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
    final input = _formatPrice(inputPrice);
    final output = _formatPrice(outputPrice);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4CF086).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$input → $output',
        style: const TextStyle(
          color: Color(0xFF4CF086),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

void _showModelDetailsSheet(BuildContext context, ModelOption model) {
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
              Text(
                'Vision: $visionLabel',
                style: TextStyle(color: tokens.foreground),
              ),
              const SizedBox(height: 8),
              Text(
                'Context window: ${showInt(model.contextWindow)}',
                style: TextStyle(color: tokens.foreground),
              ),
              const SizedBox(height: 8),
              Text(
                'Max output tokens: ${showInt(model.maxOutputTokens)}',
                style: TextStyle(color: tokens.foreground),
              ),
              const SizedBox(height: 8),
              Text(
                'Input price: ${showValue(model.inputPrice)}',
                style: TextStyle(color: tokens.foreground),
              ),
              const SizedBox(height: 8),
              Text(
                'Output price: ${showValue(model.outputPrice)}',
                style: TextStyle(color: tokens.foreground),
              ),
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

class WorkspaceAttachmentPickerSheet extends StatelessWidget {
  const WorkspaceAttachmentPickerSheet({
    super.key,
    required this.onPickImages,
  });

  final Future<void> Function() onPickImages;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.image_outlined, color: tokens.accent),
              title: Text('Pick images',
                  style: TextStyle(color: tokens.foreground)),
              onTap: () async {
                Navigator.pop(context);
                await onPickImages();
              },
            ),
          ],
        ),
      ),
    );
  }
}

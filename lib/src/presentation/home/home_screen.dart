import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../components/app_ui.dart';
import 'home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.promptController,
    required this.onPromptSubmit,
    required this.onOpenSidebar,
    required this.onOpenSettings,
    required this.onOpenModels,
    required this.onContinueLastChat,
    required this.showApiWarning,
    required this.vm,
  });

  final TextEditingController promptController;
  final Future<void> Function() onPromptSubmit;
  final VoidCallback onOpenSidebar;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenModels;
  final VoidCallback onContinueLastChat;
  final bool showApiWarning;
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;

    return Column(
      children: [
        if (showApiWarning) ApiWarningBanner(onTap: onOpenSettings),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              children: [
                GidarTopBar(
                  title: 'Gidar AI',
                  onLeadingTap: onOpenSidebar,
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _HeroPanel(theme: theme, vm: vm),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Quick Actions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: tokens.foreground,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _QuickActionChip(
                                  icon: Icons.add_comment_rounded,
                                  label: 'New Chat',
                                  onTap: promptController.clear,
                                ),
                                _QuickActionChip(
                                  icon: Icons.history_rounded,
                                  label: 'Continue Last',
                                  onTap: onContinueLastChat,
                                ),
                                _QuickActionChip(
                                  icon: Icons.layers_rounded,
                                  label: 'Browse Models',
                                  onTap: onOpenModels,
                                ),
                                _QuickActionChip(
                                  icon: Icons.settings_suggest_rounded,
                                  label: 'Provider Health',
                                  onTap: onOpenSettings,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _ProviderReadinessCard(theme: theme, vm: vm),
                            const Spacer(),
                            SizedBox(
                              height: constraints.maxHeight < 620 ? 120 : 148,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.theme,
    required this.vm,
  });

  final ThemeData theme;
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.panelSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const HeroLogo(size: 118),
          const SizedBox(height: 14),
          Text(
            'GIDAR AI',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              textStyle: theme.textTheme.headlineSmall,
              color: tokens.foreground,
              fontWeight: FontWeight.w700,
              fontSize: 27,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DashboardStatTile(
                label: 'Provider',
                value: vm.activeProviderLabel,
                icon: Icons.hub_rounded,
              ),
              _DashboardStatTile(
                label: 'Filter',
                value: vm.selectedProviderLabel,
                icon: Icons.filter_alt_rounded,
              ),
              _DashboardStatTile(
                label: 'Enabled',
                value: '${vm.enabledProviderCount} providers',
                icon: Icons.toggle_on_rounded,
              ),
              _DashboardStatTile(
                label: 'Readiness',
                value: vm.missingProviderCount == 0
                    ? 'All keys ready'
                    : '${vm.missingProviderCount} missing',
                icon: Icons.verified_rounded,
                warning: vm.missingProviderCount > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProviderReadinessCard extends StatelessWidget {
  const _ProviderReadinessCard({
    required this.theme,
    required this.vm,
  });

  final ThemeData theme;
  final HomeViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provider readiness',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  vm.missingProviderCount == 0
                      ? 'All enabled provider keys are configured and ready.'
                      : '${vm.missingProviderCount} enabled providers still need keys.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: vm.missingProviderCount == 0
                        ? tokens.mutedForeground
                        : const Color(0xFFFFB289),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            vm.missingProviderCount == 0
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            color: vm.missingProviderCount == 0
                ? const Color(0xFF4CF086)
                : const Color(0xFFFFB289),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _DashboardStatTile extends StatelessWidget {
  const _DashboardStatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appThemeTokens;
    return Container(
      width: 148,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: tokens.elevatedSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.mutedBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                warning ? const Color(0xFFFFB289) : theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tokens.mutedForeground,
              letterSpacing: 0.4,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: warning ? const Color(0xFFFFC39E) : tokens.foreground,
              height: 1.2,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appThemeTokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: tokens.chipSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tokens.mutedBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tokens.accent),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    color: tokens.foreground,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

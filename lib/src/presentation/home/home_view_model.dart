import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';

class HomeSuggestion {
  const HomeSuggestion({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

class HomeViewModel {
  const HomeViewModel({
    required this.showApiWarning,
    required this.selectedModelName,
    required this.suggestions,
    required this.activeProviderLabel,
    required this.selectedProviderLabel,
    required this.enabledProviderCount,
    required this.missingProviderCount,
    required this.hasLastChat,
  });

  final bool showApiWarning;
  final String selectedModelName;
  final List<HomeSuggestion> suggestions;
  final String activeProviderLabel;
  final String selectedProviderLabel;
  final int enabledProviderCount;
  final int missingProviderCount;
  final bool hasLastChat;
}

final homeViewModelProvider = Provider<HomeViewModel>(
  (ref) {
    final controller = ref.watch(appControllerProvider);
    return HomeViewModel(
      showApiWarning: controller.apiKey.isEmpty,
      selectedModelName: controller.selectedModel?.name ?? 'No model selected',
      activeProviderLabel: controller.activeProviderLabel,
      selectedProviderLabel: controller.selectedProviderLabel,
      enabledProviderCount: controller.enabledProviders.length,
      missingProviderCount: controller.enabledProviders
          .where((provider) => !controller.hasKeyForProvider(provider))
          .length,
      hasLastChat: controller.sessions.isNotEmpty,
      suggestions: const [
        HomeSuggestion(
          title: 'Explain quantum computing',
          subtitle: 'Simplified for a beginner',
          icon: Icons.auto_awesome_rounded,
        ),
        HomeSuggestion(
          title: 'Write a Python script',
          subtitle: 'Automation and data parsing',
          icon: Icons.terminal_rounded,
        ),
        HomeSuggestion(
          title: 'Plan a trip to Goa',
          subtitle: 'Beaches and hidden gems',
          icon: Icons.map_rounded,
        ),
        HomeSuggestion(
          title: 'Summarize this text',
          subtitle: 'Extract key bullet points',
          icon: Icons.description_outlined,
        ),
      ],
    );
  },
  dependencies: [appControllerProvider],
);

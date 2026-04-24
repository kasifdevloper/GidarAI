import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_models.dart';
import '../../core/providers/app_providers.dart';
import '../../presentation/workspace/workspace_screen.dart';

enum GidarRouteTab {
  home(0),
  chat(1),
  settings(2);

  const GidarRouteTab(this.tabIndex);
  final int tabIndex;
}

final appRouterProvider = Provider<GoRouter>(
  (ref) {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _RouteWorkspace(tab: GidarRouteTab.home),
          ),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _RouteWorkspace(tab: GidarRouteTab.chat),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _RouteWorkspace(
              tab: GidarRouteTab.settings,
              settingsSection: SettingsSection.overview,
            ),
          ),
          routes: [
            _settingsRoute('providers', SettingsSection.providers),
            _settingsRoute('models', SettingsSection.models),
            _settingsRoute('system-prompt', SettingsSection.systemPrompt),
            _settingsRoute('appearance', SettingsSection.appearance),
            _settingsRoute('chat-data', SettingsSection.chatData),
            _settingsRoute('about', SettingsSection.about),
          ],
        ),
      ],
    );
  },
  dependencies: [appControllerProvider],
);

class _RouteWorkspace extends ConsumerWidget {
  const _RouteWorkspace({
    required this.tab,
    this.settingsSection,
  });

  final GidarRouteTab tab;
  final SettingsSection? settingsSection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider);
    final currentIndex = ref.watch(
      appControllerProvider.select((value) => value.currentIndex),
    );
    if (currentIndex != tab.tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setTab(tab.tabIndex);
      });
    }
    return WorkspaceScreen(
      settingsSection: settingsSection ?? SettingsSection.overview,
    );
  }
}

GoRoute _settingsRoute(String path, SettingsSection section) {
  return GoRoute(
    path: path,
    name: 'settings-${section.name}',
    pageBuilder: (context, state) => NoTransitionPage(
      child: _RouteWorkspace(
        tab: GidarRouteTab.settings,
        settingsSection: section,
      ),
    ),
  );
}

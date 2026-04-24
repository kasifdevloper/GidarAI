import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app/gidar_app.dart';
import 'src/core/models/app_models.dart';
import 'src/core/services/app_controller.dart';
import 'src/data/repository/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences? initialSharedPreferences;
  AppSettings? initialSettings;
  List<ChatSession> initialSidebarSessions = const <ChatSession>[];
  AppController? initialController;

  try {
    initialSharedPreferences = await SharedPreferences.getInstance();
    final settingsRepository = SettingsRepository(initialSharedPreferences);
    initialSettings = await settingsRepository.loadSettings();
    initialSidebarSessions = settingsRepository.loadSidebarCache();
    initialController = AppController(
      initialSettings: initialSettings,
      initialSharedPreferences: initialSharedPreferences,
      initialSidebarSessions: initialSidebarSessions,
    );
    await initialController.initialize();
  } catch (_) {
    initialController?.dispose();
    initialController = null;
  }

  runApp(
    ProviderScope(
      child: GidarApp(
        appController: initialController,
        initialSettings: initialSettings,
        initialSharedPreferences: initialSharedPreferences,
        initialSidebarSessions: initialSidebarSessions,
      ),
    ),
  );
}

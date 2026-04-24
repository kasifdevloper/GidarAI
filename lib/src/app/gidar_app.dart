import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/router/app_router.dart';
import '../core/models/app_models.dart';
import '../core/providers/app_providers.dart';
import '../core/services/app_controller.dart';
import '../core/theme/app_theme.dart';

class GidarApp extends ConsumerStatefulWidget {
  const GidarApp({
    super.key,
    this.appController,
    this.initialSettings,
    this.initialSharedPreferences,
    this.initialSidebarSessions = const <ChatSession>[],
  });

  final AppController? appController;
  final AppSettings? initialSettings;
  final SharedPreferences? initialSharedPreferences;
  final List<ChatSession> initialSidebarSessions;

  @override
  ConsumerState<GidarApp> createState() => _GidarAppState();
}

class _GidarAppState extends ConsumerState<GidarApp> {
  late final AppController _controller = widget.appController ??
      AppController(
        initialSettings: widget.initialSettings,
        initialSharedPreferences: widget.initialSharedPreferences,
        initialSidebarSessions: widget.initialSidebarSessions,
      );
  late final bool _ownsController = widget.appController == null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_ownsController) {
      _controller.initializeForApp();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((ref) => _controller),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final liveController = ref.read(appControllerProvider);
          final outerRouter = ref.watch(appRouterProvider);
          final themeMode = ref.watch(
            appControllerProvider.select((controller) => controller.themeMode),
          );
          final appearanceMode = ref.watch(
            appControllerProvider.select(
              (controller) => controller.appearanceMode,
            ),
          );
          final dynamicThemeEnabled = ref.watch(
            appControllerProvider.select(
              (controller) => controller.dynamicThemeEnabled,
            ),
          );
          final appFontPreset = ref.watch(
            appControllerProvider
                .select((controller) => controller.appFontPreset),
          );
          final chatFontPreset = ref.watch(
            appControllerProvider
                .select((controller) => controller.chatFontPreset),
          );
          final chatColorMode = ref.watch(
            appControllerProvider
                .select((controller) => controller.chatColorMode),
          );
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                liveController.setDynamicThemeAvailability(
                  lightDynamic != null || darkDynamic != null,
                );
              });

              final palette = paletteFor(themeMode);
              final lightTheme = dynamicThemeEnabled && lightDynamic != null
                  ? buildDynamicTheme(
                      lightDynamic,
                      appFontPreset: appFontPreset,
                      chatFontPreset: chatFontPreset,
                      chatColorMode: chatColorMode,
                    )
                  : buildTheme(
                      palette,
                      brightness: Brightness.light,
                      appFontPreset: appFontPreset,
                      chatFontPreset: chatFontPreset,
                      chatColorMode: chatColorMode,
                    );
              final darkTheme = dynamicThemeEnabled && darkDynamic != null
                  ? buildDynamicTheme(
                      darkDynamic,
                      appFontPreset: appFontPreset,
                      chatFontPreset: chatFontPreset,
                      chatColorMode: chatColorMode,
                    )
                  : buildTheme(
                      palette,
                      brightness: Brightness.dark,
                      appFontPreset: appFontPreset,
                      chatFontPreset: chatFontPreset,
                      chatColorMode: chatColorMode,
                    );

              return MaterialApp.router(
                debugShowCheckedModeBanner: false,
                title: 'Gidar AI',
                theme: lightTheme,
                darkTheme: darkTheme,
                themeMode: materialThemeModeFor(appearanceMode),
                routerConfig: outerRouter,
                builder: (context, child) {
                  final activeTheme = Theme.of(context);
                  final overlayBase = activeTheme.brightness == Brightness.light
                      ? SystemUiOverlayStyle.dark
                      : SystemUiOverlayStyle.light;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlayBase.copyWith(
                      statusBarColor: Colors.transparent,
                      systemNavigationBarColor: Colors.transparent,
                      systemNavigationBarDividerColor: Colors.transparent,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

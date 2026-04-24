import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/app/router/app_router.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/core/providers/app_providers.dart';
import 'package:gidar_ai_flutter/src/core/services/app_controller.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_session_store.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_streaming_coordinator.dart';
import 'package:gidar_ai_flutter/src/data/remote/openrouter_remote_data_source.dart';
import 'package:gidar_ai_flutter/src/data/repository/chat_completion_repository.dart';
import 'package:gidar_ai_flutter/src/data/repository/settings_repository.dart';
import 'package:gidar_ai_flutter/src/presentation/components/app_ui.dart';
import 'package:gidar_ai_flutter/src/presentation/components/message_item.dart';
import 'package:gidar_ai_flutter/src/presentation/settings/settings_actions.dart';
import 'package:gidar_ai_flutter/src/presentation/settings/settings_screen.dart';
import 'package:gidar_ai_flutter/src/presentation/settings/settings_view_model.dart';
import 'package:gidar_ai_flutter/src/core/theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('controller selectedProviderLabel uses custom provider name', () async {
    final controller = _buildTestController(
      initialSettings: const AppSettings(
        apiKey: '',
        providerKeys: ProviderKeys(),
        customProvider: CustomProviderConfig(
          id: 'gateway-a',
          name: 'Gateway A',
          enabled: true,
        ),
        customProviders: [
          CustomProviderConfig(
            id: 'gateway-a',
            name: 'Gateway A',
            enabled: true,
          ),
          CustomProviderConfig(
            id: 'gateway-b',
            name: 'Gateway B',
            enabled: true,
          ),
        ],
        selectedModel: null,
        selectedProvider: AiProviderType.custom,
        systemPrompt: '',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.system,
        dynamicThemeEnabled: true,
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: [AiProviderType.custom],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.systemDynamic,
        chatFontPreset: AppFontPreset.notoSansDevanagari,
        chatColorMode: ChatColorMode.theme,
      ),
    );

    await controller.initialize();
    controller.selectProvider(
      AiProviderType.custom,
      customProviderId: 'gateway-b',
    );

    expect(controller.selectedProviderLabel, 'Gateway B');
  });

  testWidgets('providers settings screen saves entered API keys',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController();
    final recordingActions = _RecordingSettingsActions();
    await controller.initialize();
    final apiKeyController = TextEditingController();
    final systemPromptController = TextEditingController();
    addTearDown(apiKeyController.dispose);
    addTearDown(systemPromptController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          settingsActionsProvider.overrideWithValue(recordingActions),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              apiKeyController: apiKeyController,
              systemPromptController: systemPromptController,
              obscureApiKey: true,
              onToggleObscure: () {},
              onOpenSidebar: () {},
              section: SettingsSection.providers,
              onOpenSection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Gemini').first);
    await tester.pumpAndSettle();

    final geminiField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Enter Gemini API key',
    );
    await tester.enterText(geminiField, 'gemini-key-123');
    await tester.tap(find.text('Save Key').first);
    await tester.pumpAndSettle();

    expect(recordingActions.savedForms, hasLength(1));
    expect(recordingActions.savedForms.single.geminiKey, 'gemini-key-123');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
      'providers settings screen can add multiple custom providers and delete one',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController(
      initialSettings: const AppSettings(
        apiKey: '',
        providerKeys: ProviderKeys(),
        customProvider: CustomProviderConfig(
          id: 'custom-seed',
          enabled: true,
        ),
        customProviders: [
          CustomProviderConfig(
            id: 'custom-seed',
            enabled: true,
          ),
        ],
        selectedModel: null,
        selectedProvider: AiProviderType.custom,
        systemPrompt: '',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.system,
        dynamicThemeEnabled: true,
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: [AiProviderType.custom],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.systemDynamic,
        chatFontPreset: AppFontPreset.notoSansDevanagari,
        chatColorMode: ChatColorMode.theme,
      ),
    );
    await controller.initialize();
    final apiKeyController = TextEditingController();
    final systemPromptController = TextEditingController();
    addTearDown(apiKeyController.dispose);
    addTearDown(systemPromptController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              apiKeyController: apiKeyController,
              systemPromptController: systemPromptController,
              obscureApiKey: true,
              onToggleObscure: () {},
              onOpenSidebar: () {},
              section: SettingsSection.providers,
              onOpenSection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder buttonFor(String text) => find
        .ancestor(
          of: find.text(text).last,
          matching:
              find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
        )
        .first;
    Finder saveButton() {
      final label = find.text('Save').evaluate().isNotEmpty ? 'Save' : 'Saved';
      return buttonFor(label);
    }

    expect(find.text('Add'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Provider name',
      ),
      'My Gateway',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'https://api.example.com/v1',
      ),
      'https://api.example.com/v1',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Enter Custom API key',
      ),
      'custom-key-1',
    );
    await tester.tap(saveButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('My Gateway'), findsOneWidget);
    expect(controller.customProviders, hasLength(1));

    await tester.tap(buttonFor('Add'));
    await tester.pumpAndSettle();
    expect(controller.customProviders, hasLength(2));
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Provider name',
      ),
      'Second Gateway',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'https://api.example.com/v1',
      ),
      'https://second.example.com/v1',
    );
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Enter Custom API key',
      ),
      'custom-key-2',
    );
    await tester.tap(saveButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Second Gateway'), findsWidgets);
    expect(controller.customProviders, hasLength(2));
    expect(
      controller.customProviders.map((provider) => provider.normalizedName),
      containsAll(['My Gateway', 'Second Gateway']),
    );

    await tester.tap(buttonFor('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(buttonFor('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.customProviders, hasLength(1));
    expect(
      controller.customProviders.single.normalizedName,
      anyOf('My Gateway', 'Second Gateway'),
    );
    expect(
      controller.models
          .where((model) => model.provider == AiProviderType.custom),
      isEmpty,
    );
  });

  testWidgets('system prompt settings keeps core presets without tutor chip',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController();
    final recordingActions = _RecordingSettingsActions();
    await controller.initialize();
    final apiKeyController = TextEditingController();
    final systemPromptController = TextEditingController();
    addTearDown(apiKeyController.dispose);
    addTearDown(systemPromptController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          settingsActionsProvider.overrideWithValue(recordingActions),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(
              apiKeyController: apiKeyController,
              systemPromptController: systemPromptController,
              obscureApiKey: true,
              onToggleObscure: () {},
              onOpenSidebar: () {},
              section: SettingsSection.systemPrompt,
              onOpenSection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student Tutor'), findsNothing);
    expect(find.text('Coding Assistant'), findsOneWidget);
    expect(find.text('Research Analyst'), findsOneWidget);
    expect(recordingActions.savedForms, isEmpty);
  });

  testWidgets('workspace send flow routes to chat and renders streamed reply', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController(
      repository: ChatCompletionRepository(
        openRouterRemoteDataSource: _FakeOpenRouterRemoteDataSource(
          onStream: ({
            required apiKey,
            required model,
            required systemPrompt,
            required history,
          }) {
            expect(apiKey, 'openrouter-key');
            expect(history.single.promptText, 'Hello from widget test');
            return Stream<String>.fromIterable(const ['Hello', ' back']);
          },
        ),
      ),
    );

    await controller.initialize();
    final openRouterModel = SettingsRepository.builtInModels.firstWhere(
      (model) => model.provider == AiProviderType.openRouter,
    );
    await controller.saveSettings(
      apiKey: 'openrouter-key',
      systemPrompt: 'Be helpful.',
      model: openRouterModel,
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.sourceSans3,
      providerKeys: const ProviderKeys(openRouter: 'openrouter-key'),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.openRouter],
      uiDensityMode: UiDensityMode.compact,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: const _RouterHarness(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Message Gidar AI...'),
      'Hello from widget test',
    );
    await tester.tap(find.byIcon(Icons.send_rounded).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hello from widget test'), findsWidgets);
    expect(find.text('Hello back'), findsOneWidget);
    expect(controller.currentIndex, GidarRouteTab.chat.tabIndex);
    expect(controller.selectedSession?.messages.last.content, 'Hello back');
  });

  testWidgets('android back from settings returns to home instead of closing',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController();
    await controller.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: const _RouterHarness(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Provider Health'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Press back again to exit.'), findsNothing);
  });

  testWidgets(
    'editing the last user message removes the old assistant reply before resend',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = _buildTestController(
        repository: ChatCompletionRepository(
          openRouterRemoteDataSource: _FakeOpenRouterRemoteDataSource(
            onStream: ({
              required apiKey,
              required model,
              required systemPrompt,
              required history,
            }) {
              final latestPrompt = history.last.promptText;
              if (latestPrompt == 'Apple kya hai?') {
                return Stream<String>.fromIterable(
                  const ['Apple ek phal hai...'],
                );
              }
              if (latestPrompt == 'Apple company kya hai?') {
                expect(history, hasLength(1));
                expect(history.single.role, 'user');
                return (() async* {
                  yield 'Apple ek ';
                  await Future<void>.delayed(const Duration(milliseconds: 30));
                  yield 'tech company hai...';
                })();
              }
              return const Stream<String>.empty();
            },
          ),
        ),
      );

      await controller.initialize();
      final openRouterModel = SettingsRepository.builtInModels.firstWhere(
        (model) => model.provider == AiProviderType.openRouter,
      );
      await controller.saveSettings(
        apiKey: 'openrouter-key',
        systemPrompt: 'Be helpful.',
        model: openRouterModel,
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.dark,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.sourceSans3,
        providerKeys: const ProviderKeys(openRouter: 'openrouter-key'),
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.openRouter],
        uiDensityMode: UiDensityMode.compact,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
          ],
          child: const _RouterHarness(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Message Gidar AI...'),
        'Apple kya hai?',
      );
      await tester.tap(find.byIcon(Icons.send_rounded).last);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Apple ek phal hai...'), findsOneWidget);

      await tester.tap(find.text('Apple kya hai?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Editing last message'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField).last);
      expect(textField.controller?.text, 'Apple kya hai?');

      await tester.enterText(
        find.byType(TextField).last,
        'Apple company kya hai?',
      );
      await tester.tap(find.byIcon(Icons.send_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      final inFlightMessages = controller.selectedSession!.messages;
      expect(inFlightMessages.first.content, 'Apple company kya hai?');
      expect(
        inFlightMessages
            .any((message) => message.content == 'Apple ek phal hai...'),
        isFalse,
      );
      expect(controller.isStreaming, isTrue);

      for (var i = 0; i < 6; i++) {
        if (controller.streamingDraft.isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(controller.streamingDraft, isNotEmpty);
      expect(controller.selectedSession!.messages, hasLength(1));

      for (var i = 0; i < 6; i++) {
        if (controller.selectedSession!.messages.length == 2) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(controller.selectedSession!.messages, hasLength(2));
      expect(
        controller.selectedSession!.messages.first.content,
        'Apple company kya hai?',
      );
      expect(
        controller.selectedSession!.messages.last.content,
        'Apple ek tech company hai...',
      );
    },
  );

  testWidgets(
      'follow-up user message stays below the top bar after a long reply',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longReply = '''
Line 01
Line 02
Line 03
Line 04
Line 05
Line 06
Line 07
Line 08
Line 09
Line 10
Line 11
Line 12
Line 13
Line 14
Line 15
Line 16
Line 17
Line 18
Line 19
Line 20
Line 21
Line 22
Line 23
Line 24
Line 25
Line 26
Line 27
Line 28
Line 29
Line 30
Line 31
Line 32
Line 33
Line 34
Line 35
Line 36
Line 37
Line 38
Line 39
Line 40
''';

    final controller = _buildTestController(
      repository: ChatCompletionRepository(
        openRouterRemoteDataSource: _FakeOpenRouterRemoteDataSource(
          onStream: ({
            required apiKey,
            required model,
            required systemPrompt,
            required history,
          }) {
            final latestPrompt = history.last.promptText;
            if (latestPrompt == 'First long prompt') {
              return Stream<String>.fromIterable(const [longReply]);
            }
            if (latestPrompt == 'Second question') {
              return Stream<String>.fromIterable(const ['Short follow-up']);
            }
            return const Stream<String>.empty();
          },
        ),
      ),
    );

    await controller.initialize();
    final openRouterModel = SettingsRepository.builtInModels.firstWhere(
      (model) => model.provider == AiProviderType.openRouter,
    );
    await controller.saveSettings(
      apiKey: 'openrouter-key',
      systemPrompt: 'Be helpful.',
      model: openRouterModel,
      themeMode: AppThemeMode.classicDark,
      appearanceMode: AppAppearanceMode.dark,
      appFontPreset: AppFontPreset.inter,
      chatFontPreset: AppFontPreset.sourceSans3,
      providerKeys: const ProviderKeys(openRouter: 'openrouter-key'),
      routingMode: ChatRoutingMode.directModel,
      enabledProviders: const [AiProviderType.openRouter],
      uiDensityMode: UiDensityMode.compact,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: const _RouterHarness(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> sendPrompt(String text) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Message Gidar AI...'),
        text,
      );
      await tester.tap(find.byIcon(Icons.send_rounded).last);
      await tester.pump();
    }

    await sendPrompt('First long prompt');
    await tester.pumpAndSettle();
    expect(find.textContaining('Line 40'), findsOneWidget);

    await sendPrompt('Second question');

    final topBarFinder = find.byType(GidarTopBar);
    final secondMessageFinder = find.ancestor(
      of: find.text('Second question'),
      matching: find.byType(UserMessageBubble),
    );

    void expectMessageBelowTopBar() {
      final topBarBottom = tester.getBottomLeft(topBarFinder).dy;
      final secondMessageTop = tester.getTopLeft(secondMessageFinder).dy;
      expect(secondMessageTop, greaterThanOrEqualTo(topBarBottom));
    }

    await tester.pumpAndSettle();
    expectMessageBelowTopBar();

    expect(find.text('Short follow-up'), findsOneWidget);
  });

  testWidgets('appearance settings expose app and chat font controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController();
    final recordingActions = _RecordingSettingsActions();
    await controller.initialize();
    final apiKeyController = TextEditingController();
    final systemPromptController = TextEditingController();
    addTearDown(apiKeyController.dispose);
    addTearDown(systemPromptController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          settingsActionsProvider.overrideWithValue(recordingActions),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: SettingsScreen(
              apiKeyController: apiKeyController,
              systemPromptController: systemPromptController,
              obscureApiKey: true,
              onToggleObscure: () {},
              onOpenSidebar: () {},
              section: SettingsSection.appearance,
              onOpenSection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('APP FONT'), findsOneWidget);
    expect(find.text('CHAT FONT'), findsOneWidget);
    expect(find.text('CHAT COLOUR'), findsOneWidget);
    expect(find.text('System Dynamic'), findsNWidgets(2));
    expect(find.byIcon(Icons.search_rounded), findsNothing);

    final appCard = find.byKey(const ValueKey('app-font-preference-card'));
    final appRails = find.descendant(
      of: appCard,
      matching: find.byType(SingleChildScrollView),
    );
    await tester.dragUntilVisible(
      find.text('Roboto').first,
      appRails.first,
      const Offset(-240, 0),
    );
    await tester.tap(find.text('Roboto').first);
    await tester.pumpAndSettle();

    final chatCard = find.byKey(const ValueKey('chat-font-preference-card'));
    await tester.scrollUntilVisible(
      chatCard,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(of: chatCard, matching: find.text('Best picks')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chatCard, matching: find.text('More fonts')),
      findsOneWidget,
    );

    expect(
        recordingActions.savedAppFontPresets, contains(AppFontPreset.roboto));
  });

  testWidgets('appearance font browser supports horizontal font rails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _buildTestController();
    final recordingActions = _RecordingSettingsActions();
    await controller.initialize();
    final apiKeyController = TextEditingController();
    final systemPromptController = TextEditingController();
    addTearDown(apiKeyController.dispose);
    addTearDown(systemPromptController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
          settingsActionsProvider.overrideWithValue(recordingActions),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: SettingsScreen(
              apiKeyController: apiKeyController,
              systemPromptController: systemPromptController,
              obscureApiKey: true,
              onToggleObscure: () {},
              onOpenSidebar: () {},
              section: SettingsSection.appearance,
              onOpenSection: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appCard = find.byKey(const ValueKey('app-font-preference-card'));
    final appRails = find.descendant(
      of: appCard,
      matching: find.byType(SingleChildScrollView),
    );
    expect(appRails, findsNWidgets(2));
    expect(find.text('Best picks'), findsWidgets);
    expect(find.text('More fonts'), findsWidgets);
    expect(find.byIcon(Icons.search_rounded), findsNothing);

    await tester.tap(find.text('Manrope').first);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: appCard, matching: find.text('System Dynamic')).first,
    );
    await tester.pumpAndSettle();

    expect(
      recordingActions.savedAppFontPresets,
      containsAll([AppFontPreset.manrope, AppFontPreset.systemDynamic]),
    );
  });
}

class _RouterHarness extends ConsumerWidget {
  const _RouterHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

AppController _buildTestController({
  ChatCompletionRepository? repository,
  AppSettings? initialSettings,
}) {
  return AppController(
    chatCompletionRepository: repository ?? ChatCompletionRepository(),
    initialSettings: initialSettings,
    packageInfoLoader: () async => PackageInfo(
      appName: 'Gidar AI',
      packageName: 'com.example.gidar',
      version: '2.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    ),
    sharedPreferencesLoader: SharedPreferences.getInstance,
    settingsRepositoryFactory: (prefs) => SettingsRepository(
      prefs,
      secureStorage: _FakeSecureStorage(),
    ),
    chatSessionStoreFactory: _buildInMemoryChatStore,
    chatStreamingCoordinatorFactory: (streamFactory) =>
        ChatStreamingCoordinator(
      streamFactory: streamFactory,
    ),
  );
}

ChatSessionStore _buildInMemoryChatStore() {
  final savedSessions = <String, ChatSession>{};
  return ChatSessionStore(
    loadAllChats: () async => savedSessions.values.toList(),
    saveChat: (session) async {
      savedSessions[session.id] = session;
    },
    deleteChat: (id) async {
      savedSessions.remove(id);
    },
    clearAllChats: () async {
      savedSessions.clear();
    },
  );
}

typedef _OnStream = Stream<String> Function({
  required String apiKey,
  required ModelOption model,
  required String systemPrompt,
  required List<ChatMessage> history,
});

class _FakeOpenRouterRemoteDataSource extends OpenRouterRemoteDataSource {
  _FakeOpenRouterRemoteDataSource({required _OnStream onStream})
      : _onStream = onStream;

  final _OnStream _onStream;

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required ModelOption model,
    required String systemPrompt,
    required List<ChatMessage> history,
  }) {
    return _onStream(
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      history: history,
    );
  }

  @override
  void dispose() {}
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _values.remove(key);
  }
}

class _RecordingSettingsActions extends SettingsActions {
  _RecordingSettingsActions() : super.test();

  final List<SettingsFormSnapshot> savedForms = <SettingsFormSnapshot>[];
  final List<AppFontPreset?> savedAppFontPresets = <AppFontPreset?>[];
  final List<AppFontPreset?> savedChatFontPresets = <AppFontPreset?>[];
  final List<ChatColorMode?> savedChatColorModes = <ChatColorMode?>[];

  @override
  Future<void> save({
    required SettingsViewModel vm,
    required SettingsFormSnapshot form,
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
  }) async {
    savedForms.add(form);
    savedAppFontPresets.add(appFontPreset);
    savedChatFontPresets.add(chatFontPreset);
    savedChatColorModes.add(chatColorMode);
  }
}

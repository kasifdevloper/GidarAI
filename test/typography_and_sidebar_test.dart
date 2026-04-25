import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/core/providers/app_providers.dart';
import 'package:gidar_ai_flutter/src/core/services/app_controller.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_session_store.dart';
import 'package:gidar_ai_flutter/src/core/services/chat_streaming_coordinator.dart';
import 'package:gidar_ai_flutter/src/core/theme/app_theme.dart';
import 'package:gidar_ai_flutter/src/presentation/components/app_ui.dart';
import 'package:gidar_ai_flutter/src/presentation/components/code_utils.dart';
import 'package:gidar_ai_flutter/src/presentation/components/message_item.dart';
import 'package:gidar_ai_flutter/src/presentation/sidebar/sidebar_drawer.dart';
import 'package:gidar_ai_flutter/src/presentation/workspace/workspace_overlays.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('chat font applies to user bubble while code stays monospace', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.kalam,
        ),
        home: Scaffold(
          body: Column(
            children: [
              UserMessageBubble(
                message: ChatMessage(
                  id: '1',
                  role: 'user',
                  content: 'नमस्ते world',
                  createdAt: DateTime(2024),
                ),
              ),
              const CodePanel(codeBlock: '```dart\nprint("hi");\n```'),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final messageText = tester.widget<Text>(find.text('नमस्ते world'));
    final codeHeader = tester.widget<Text>(find.text('dart'));

    expect(messageText.style?.fontFamily, contains('Kalam'));
    expect(codeHeader.style?.fontFamily, 'monospace');
  });

  testWidgets('theme typography stays Devanagari-safe with registered fallback',
      (tester) async {
    late ThemeData theme;
    late AppTypography typography;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.light,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.openSans,
        ),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            typography = context.appTypography;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    expect(theme.textTheme.bodyMedium?.letterSpacing, 0);
    expect(theme.textTheme.titleLarge?.letterSpacing, 0);
    expect(theme.inputDecorationTheme.hintStyle?.letterSpacing, 0);
    expect(typography.chatBody.letterSpacing, 0);
    expect(typography.sidebarSectionLabel.letterSpacing, 0);
    expect(theme.textTheme.bodyMedium?.wordSpacing, 0.1);
    expect(typography.chatBody.wordSpacing, 0.1);
    expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w500);
    expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback, contains('NirmalaUI'));
    expect(typography.chatBody.fontFamilyFallback, contains('NirmalaUI'));
  });

  testWidgets('gidar top bar keeps a visible card shell across themes', (
    tester,
  ) async {
    Future<void> pumpFor(Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: brightness,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: const Scaffold(
            body: GidarTopBar(title: 'Gidar AI'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shell = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.padding ==
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
      );
      final decoration = shell.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
    }

    await pumpFor(Brightness.dark);
    await pumpFor(Brightness.light);
  });

  testWidgets('assistant markdown styles emphasize headings, tables, and code',
      (
    tester,
  ) async {
    late MarkdownStyleSheet styleSheet;
    late Map<String, TextStyle> codeTheme;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.light,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Builder(
          builder: (context) {
            styleSheet = buildAssistantMarkdownStyleSheet(context);
            codeTheme = buildCodeHighlightTheme(
              tokens: context.appThemeTokens,
              brightness: Theme.of(context).brightness,
            );
            return Scaffold(
              body: AssistantMessageCard(
                message: ChatMessage(
                  id: 'assistant-1',
                  role: 'assistant',
                  content:
                      '# Main Point\n\n- Bullet item\n\n| Col | Val |\n| --- | --- |\n| A | B |\n\n```dart\nfinal value = 1;\n```',
                  createdAt: DateTime(2024),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(styleSheet.h1?.color, isNot(styleSheet.p?.color));
    expect(styleSheet.h2?.color, isNot(styleSheet.p?.color));
    expect(styleSheet.strong?.color, isNot(styleSheet.p?.color));
    expect(styleSheet.tableBorder, isNotNull);
    expect(styleSheet.tableBorder?.borderRadius, BorderRadius.circular(18));
    expect(styleSheet.tableCellsDecoration, isNotNull);
    expect(styleSheet.tableColumnWidth, isA<IntrinsicColumnWidth>());
    expect(styleSheet.listBullet?.color, styleSheet.p?.color);
    expect(codeTheme['keyword']?.color, isNot(codeTheme['root']?.color));
    expect(find.text('Main Point'), findsOneWidget);
    expect(find.text('Bullet item'), findsOneWidget);
    expect(find.text('Col'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
  });

  testWidgets('assistant math formulas render as math widgets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-math',
              role: 'assistant',
              content: r'''
Area formula is $A = \pi r^2$.

$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$
''',
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining('Area formula is'), findsOneWidget);
  });

  testWidgets(
      'streaming and settled assistant both keep mixed inline formulas rendered',
      (tester) async {
    const reply = r'''
A. संवेग (Momentum) का सूत्र: $$p = m \times v$$ p = संवेग (Momentum)

B. बल (Force) का सूत्र: $$F = m \times a$$ F = बल (Force)
''';

    Future<void> pumpCard({required bool isGenerating}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.sourceSans3,
          ),
          home: Scaffold(
            body: AssistantMessageCard(
              message: ChatMessage(
                id: 'assistant-inline-math',
                role: 'assistant',
                content: reply,
                createdAt: DateTime(2024),
              ),
              isGenerating: isGenerating,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    await pumpCard(isGenerating: true);
    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining(r'$$p = m \times v$$'), findsNothing);

    await pumpCard(isGenerating: false);
    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining(r'$$F = m \times a$$'), findsNothing);
  });

  testWidgets('mixed hindi english inline display math stays rendered in prose',
      (tester) async {
    const reply = r'''
A. संवेग (Momentum) का सूत्र: $$p = m \times v$$ p = संवेग (Momentum)

C. संवेग परिवर्तन की दर: $$F = \frac{mv - mu}{t}$$ यहाँ v = अंतिम वेग, u = प्रारंभिक वेग, और t = समय है।
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-mixed-inline-math',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining(r'$$'), findsNothing);
    expect(find.textContaining(r'\frac{mv - mu}{t}'), findsNothing);
  });

  testWidgets('loose gemini style sections normalize into cleaner markdown',
      (tester) async {
    const reply = r'''
A. संवेग (Momentum) का सूत्र: $$p = m \times v$$ p = संवेग (Momentum)

3. गति का तीसरा नियम (Third Law)
• वस्तु A द्वारा वस्तु B पर लगाया गया बल
• वस्तु B द्वारा वस्तु A पर बराबर और विपरीत बल
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-gemini-loose-format',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining(r'$$'), findsNothing);
    expect(find.textContaining('3. गति का तीसरा नियम'), findsOneWidget);
    expect(find.textContaining('वस्तु A द्वारा वस्तु B'), findsOneWidget);
  });

  testWidgets('standalone bold plain text formulas promote to math blocks',
      (tester) async {
    const reply = '''
फॉर्मूला:

**F = m × a**

**F_AB = - F_BA**
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-plain-formula-promotion',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Math), findsWidgets);
    expect(find.textContaining('**F = m × a**'), findsNothing);
    expect(find.textContaining('**F_AB = - F_BA**'), findsNothing);
  });

  testWidgets('table cells clean raw html list tags into readable text',
      (tester) async {
    const reply = '''
| Feature | Details |
| --- | --- |
| Output | <ul><li>Fast</li><li>Clean</li></ul> |
| Notes | Good.</li></ul> |
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-html-table',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('</li>'), findsNothing);
    expect(find.textContaining('</ul>'), findsNothing);
    expect(find.textContaining('Fast'), findsOneWidget);
    expect(find.textContaining('Clean'), findsOneWidget);
    expect(find.textContaining('Good.'), findsOneWidget);
  });

  testWidgets('large markdown tables stay rendered as tables with content',
      (tester) async {
    const reply = '''
| Topic | Details |
| --- | --- |
| Step 1 | This is a long explanation for step one that should not stay inside a tall table cell. |
| Step 2 | This is a long explanation for step two that should also move out of table layout. |
| Step 3 | This is a long explanation for step three that should also move out of table layout. |
| Step 4 | This is a long explanation for step four that should also move out of table layout. |
| Step 5 | This is a long explanation for step five that should also move out of table layout. |
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-large-table',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Topic'), findsOneWidget);
    expect(find.textContaining('Step 1'), findsOneWidget);
    expect(find.textContaining('Step 5'), findsOneWidget);
  });

  testWidgets('labeled paragraphs keep gap and alternate accent colors',
      (tester) async {
    const reply = '''
**नियम:** पहला नियम समझो और इसे याद रखो।

**उपयोग:** यह concept real life me kaam aata hai.

**उदाहरण:** cycle chalana iska simple example hai.
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-labeled-notes',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('नियम:'), findsOneWidget);
    expect(find.textContaining('उपयोग:'), findsOneWidget);
    expect(find.textContaining('उदाहरण:'), findsOneWidget);
  });

  testWidgets('thinking-tag responses render in a collapsible thinking card',
      (tester) async {
    const reply = '''
<think>
User asked for a warm hello, so I should keep this short and friendly.
</think>

Hello! How can I help you today?
''';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: Scaffold(
          body: AssistantMessageCard(
            message: ChatMessage(
              id: 'assistant-thinking',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2024),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Thinking'), findsOneWidget);
    expect(find.textContaining('How can I help you today?'), findsOneWidget);
    expect(
      find.textContaining('I should keep this short and friendly'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('assistant-thinking-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('I should keep this short and friendly'),
      findsOneWidget,
    );
  });

  testWidgets(
    'emoji numbered sections render on the standard markdown path and keep code panels',
    (tester) async {
      const tutorReply = '''
🎯 1. DIRECT ANSWER
Apple ek technology company hai.

📖 2. SIMPLE EXPLANATION
Simple words mein, Apple phones, laptops aur software banati hai.

📌 3. KEY POINTS
- iPhone banati hai
- Mac bhi banati hai
- Software services bhi deti hai

📊 4. EXTRA SECTION
```dart
void main() {
  print('Hello Apple');
}
```

📖 5. EXAMPLE
Jaise iPhone ek Apple product hai.

✨ 6. SUMMARY
Apple ek badi tech company hai.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.sourceSans3,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantMessageCard(
                message: ChatMessage(
                  id: 'assistant-tutor',
                  role: 'assistant',
                  content: tutorReply,
                  createdAt: DateTime(2024),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DIRECT ANSWER'), findsOneWidget);
      expect(find.textContaining('SIMPLE EXPLANATION'), findsOneWidget);
      expect(find.textContaining('KEY POINTS'), findsOneWidget);
      expect(find.textContaining('EXTRA SECTION'), findsOneWidget);
      expect(find.textContaining('EXAMPLE'), findsOneWidget);
      expect(find.textContaining('SUMMARY'), findsOneWidget);
      expect(find.textContaining('Apple ek technology company hai.'),
          findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
      expect(find.textContaining('Hello Apple'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('student-tutor-card-direct-answer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'streaming emoji numbered sections stay on the standard markdown path',
    (tester) async {
      const tutorReply = '''
🎯 1. DIRECT ANSWER
Apple ek technology company hai.

📖 2. SIMPLE EXPLANATION
Simple words mein, Apple phones, laptops aur software banati hai.

📌 3. KEY POINTS
- iPhone banati hai
- Mac bhi banati hai

📊 4. EXTRA SECTION
```dart
void main() {
  print('Hello Apple');
}
```

📖 5. EXAMPLE
Jaise iPhone ek Apple product hai.

✨ 6. SUMMARY
Apple ek badi tech company hai.
''';

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.sourceSans3,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantMessageCard(
                message: ChatMessage(
                  id: 'assistant-tutor-streaming',
                  role: 'assistant',
                  content: tutorReply,
                  createdAt: DateTime(2024),
                ),
                isGenerating: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.textContaining('DIRECT ANSWER'), findsOneWidget);
      expect(find.textContaining('SUMMARY'), findsOneWidget);
      expect(find.textContaining('Apple ek technology company hai.'),
          findsOneWidget);
      expect(find.byType(CodePanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey('student-tutor-card-direct-answer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'theme color mode keeps sectioned replies on the standard markdown path',
    (tester) async {
      const tutorReply = '''
🎯 1. DIRECT ANSWER
Apple ek technology company hai.

📖 2. SIMPLE EXPLANATION
Simple words mein, Apple phones, laptops aur software banati hai.

📌 3. KEY POINTS
- iPhone banati hai
- Mac bhi banati hai

📊 4. EXTRA SECTION
Extra notes.

📖 5. EXAMPLE
Jaise iPhone ek Apple product hai.

✨ 6. SUMMARY
Apple ek badi tech company hai.
''';

      final theme = buildTheme(
        paletteFor(AppThemeMode.classicDark),
        brightness: Brightness.dark,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.sourceSans3,
        chatColorMode: ChatColorMode.theme,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssistantMessageCard(
                message: ChatMessage(
                  id: 'assistant-tutor-theme',
                  role: 'assistant',
                  content: tutorReply,
                  createdAt: DateTime(2024),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('DIRECT ANSWER'), findsOneWidget);
      expect(find.textContaining('SUMMARY'), findsOneWidget);
      expect(find.textContaining('Apple ek technology company hai.'),
          findsOneWidget);
      expect(
        find.byKey(const ValueKey('student-tutor-card-direct-answer')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'plain assistant markdown keeps the existing rendering path',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.sourceSans3,
          ),
          home: Scaffold(
            body: AssistantMessageCard(
              message: ChatMessage(
                id: 'assistant-normal',
                role: 'assistant',
                content: '# Normal Reply\n\n- Point one\n- Point two',
                createdAt: DateTime(2024),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Normal Reply'), findsOneWidget);
      expect(find.text('Point one'), findsOneWidget);
      expect(find.byKey(const ValueKey('student-tutor-card-direct-answer')),
          findsNothing);
    },
  );

  testWidgets(
      'bottom prompt bar drawer shows screenshot-style actions and systematic selectors',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          paletteFor(AppThemeMode.classicDark),
          brightness: Brightness.dark,
          appFontPreset: AppFontPreset.inter,
          chatFontPreset: AppFontPreset.sourceSans3,
        ),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: _BottomPromptBarHarness(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('File'), findsNothing);
    expect(find.text('Generate Image'), findsOneWidget);
    expect(find.text('Generate Document'), findsOneWidget);
    expect(find.text('Web Search'), findsOneWidget);
    expect(find.text('Deep Research'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('All Providers'), findsOneWidget);
    expect(find.text('Gemini 2.5 Flash'), findsOneWidget);
    expect(find.text('Commands'), findsNothing);
    expect(find.text('More'), findsNothing);
  });

  testWidgets('mobile sidebar dialog renders without overflow on phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(
      chatSessionStoreFactory: () => ChatSessionStore(
        loadAllChats: () async => <ChatSession>[],
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      ),
    );
    addTearDown(controller.dispose);
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: WorkspaceSidebarDialog(
              searchController: searchController,
              onSearchChanged: () {},
              onNewChat: () {},
              onSelectChat: (_) {},
              onSelectHome: () {},
              onSelectSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gidar AI'), findsOneWidget);
    expect(find.text('Compact premium workspace'), findsNothing);
    expect(find.text('Pro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar shows skeletons while chats hydrate with no cache', (
    tester,
  ) async {
    final delayedChats = Completer<List<ChatSession>>();
    final controller = AppController(
      initialSettings: AppSettings(
        apiKey: '',
        providerKeys: const ProviderKeys(gemini: 'g-key'),
        customProvider: const CustomProviderConfig(),
        selectedModel: const ModelOption(
          name: 'Gemini Flash',
          id: 'gemini-flash',
          blurb: 'Fast',
          provider: AiProviderType.gemini,
        ),
        systemPrompt: 'Be helpful.',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.dark,
        dynamicThemeEnabled: false,
        customModels: const [],
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.gemini],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.inter,
        chatColorMode: ChatColorMode.theme,
      ),
      chatSessionStoreFactory: () => ChatSessionStore(
        loadAllChats: () => delayedChats.future,
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      ),
      packageInfoLoader: () async => PackageInfo(
        appName: 'Gidar AI',
        packageName: 'com.example.gidar',
        version: '2.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      ),
    );
    addTearDown(controller.dispose);

    unawaited(controller.initializeForApp());

    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: SidebarDrawer(
              searchController: searchController,
              onSearchChanged: () {},
              onNewChat: () {},
              onSelectChat: (_) {},
              onSelectHome: () {},
              onSelectSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('sidebar-skeleton-list')), findsOneWidget);

    delayedChats.complete([
      ChatSession(
        id: 'chat-1',
        title: 'Hydrated chat',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime.now(),
        messages: const [],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sidebar-skeleton-list')), findsNothing);
    expect(find.text('Hydrated chat'), findsOneWidget);
  });

  testWidgets('sidebar shows cached chats instantly while refreshing', (
    tester,
  ) async {
    final delayedChats = Completer<List<ChatSession>>();
    final controller = AppController(
      initialSettings: AppSettings(
        apiKey: '',
        providerKeys: const ProviderKeys(gemini: 'g-key'),
        customProvider: const CustomProviderConfig(),
        selectedModel: const ModelOption(
          name: 'Gemini Flash',
          id: 'gemini-flash',
          blurb: 'Fast',
          provider: AiProviderType.gemini,
        ),
        systemPrompt: 'Be helpful.',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.dark,
        dynamicThemeEnabled: false,
        customModels: const [],
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.gemini],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.inter,
        chatColorMode: ChatColorMode.theme,
      ),
      initialSidebarSessions: [
        ChatSession(
          id: 'cached-1',
          title: 'Cached chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          messages: const [],
        ),
      ],
      chatSessionStoreFactory: () => ChatSessionStore(
        loadAllChats: () => delayedChats.future,
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      ),
      packageInfoLoader: () async => PackageInfo(
        appName: 'Gidar AI',
        packageName: 'com.example.gidar',
        version: '2.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      ),
    );
    addTearDown(controller.dispose);

    unawaited(controller.initializeForApp());

    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: SidebarDrawer(
              searchController: searchController,
              onSearchChanged: () {},
              onNewChat: () {},
              onSelectChat: (_) {},
              onSelectHome: () {},
              onSelectSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Cached chat'), findsOneWidget);
    expect(find.byKey(const ValueKey('sidebar-skeleton-list')), findsNothing);
    expect(find.text('Refreshing chats...'), findsOneWidget);

    delayedChats.complete([
      ChatSession(
        id: 'real-1',
        title: 'Fresh chat',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime.now(),
        messages: const [],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Cached chat'), findsNothing);
    expect(find.text('Fresh chat'), findsOneWidget);
  });

  testWidgets('sidebar shows pinned chats first and starred view filters chats',
      (tester) async {
    final controller = AppController(
      initialSettings: AppSettings(
        apiKey: '',
        providerKeys: const ProviderKeys(gemini: 'g-key'),
        customProvider: const CustomProviderConfig(),
        selectedModel: const ModelOption(
          name: 'Gemini Flash',
          id: 'gemini-flash',
          blurb: 'Fast',
          provider: AiProviderType.gemini,
        ),
        systemPrompt: 'Be helpful.',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.dark,
        dynamicThemeEnabled: false,
        customModels: const [],
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.gemini],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.inter,
        chatColorMode: ChatColorMode.theme,
      ),
      initialSharedPreferences: await SharedPreferences.getInstance(),
      initialSidebarSessions: [
        ChatSession(
          id: 'pin-1',
          title: 'Pinned chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          messages: [],
          isPinned: true,
        ),
        ChatSession(
          id: 'star-1',
          title: 'Starred chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 3),
          messages: [],
          isStarred: true,
        ),
        ChatSession(
          id: 'plain-1',
          title: 'Plain chat',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
          messages: [],
        ),
      ],
      packageInfoLoader: () async => PackageInfo(
        appName: 'Gidar AI',
        packageName: 'com.example.gidar',
        version: '2.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      ),
      chatSessionStoreFactory: () => ChatSessionStore(
        loadAllChats: () async => [
          ChatSession(
            id: 'pin-1',
            title: 'Pinned chat',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 2),
            messages: [],
            isPinned: true,
          ),
          ChatSession(
            id: 'star-1',
            title: 'Starred chat',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 3),
            messages: [],
            isStarred: true,
          ),
          ChatSession(
            id: 'plain-1',
            title: 'Plain chat',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
            messages: [],
          ),
        ],
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      ),
      chatStreamingCoordinatorFactory: (streamFactory) =>
          ChatStreamingCoordinator(
        streamFactory: streamFactory,
      ),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: SidebarDrawer(
              searchController: searchController,
              onSearchChanged: () {},
              onNewChat: () {},
              onSelectChat: (_) {},
              onSelectHome: () {},
              onSelectSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PINNED'), findsOneWidget);
    expect(find.text('Pinned chat'), findsOneWidget);
    expect(find.text('Starred (1)'), findsOneWidget);

    await tester.tap(find.text('Starred (1)'));
    await tester.pumpAndSettle();

    expect(find.text('STARRED CHATS'), findsOneWidget);
    expect(find.text('Starred chat'), findsOneWidget);
    expect(find.text('Plain chat'), findsNothing);
  });

  testWidgets(
      'sidebar keeps scroll position when reopened with same controller',
      (tester) async {
    final chats = List.generate(
      20,
      (index) => ChatSession(
        id: 'chat-$index',
        title: 'Chat $index',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime.now().subtract(Duration(days: index + 2)),
        messages: const [],
      ),
    );
    final controller = AppController(
      initialSettings: AppSettings(
        apiKey: '',
        providerKeys: const ProviderKeys(gemini: 'g-key'),
        customProvider: const CustomProviderConfig(),
        selectedModel: const ModelOption(
          name: 'Gemini Flash',
          id: 'gemini-flash',
          blurb: 'Fast',
          provider: AiProviderType.gemini,
        ),
        systemPrompt: 'Be helpful.',
        themeMode: AppThemeMode.classicDark,
        appearanceMode: AppAppearanceMode.dark,
        dynamicThemeEnabled: false,
        customModels: const [],
        routingMode: ChatRoutingMode.directModel,
        enabledProviders: const [AiProviderType.gemini],
        uiDensityMode: UiDensityMode.compact,
        appFontPreset: AppFontPreset.inter,
        chatFontPreset: AppFontPreset.inter,
        chatColorMode: ChatColorMode.theme,
      ),
      initialSharedPreferences: await SharedPreferences.getInstance(),
      initialSidebarSessions: chats,
      packageInfoLoader: () async => PackageInfo(
        appName: 'Gidar AI',
        packageName: 'com.example.gidar',
        version: '2.0.0',
        buildNumber: '1',
        buildSignature: '',
        installerStore: null,
      ),
      chatSessionStoreFactory: () => ChatSessionStore(
        loadAllChats: () async => chats,
        saveChat: (_) async {},
        deleteChat: (_) async {},
        clearAllChats: () async {},
      ),
      chatStreamingCoordinatorFactory: (streamFactory) =>
          ChatStreamingCoordinator(
        streamFactory: streamFactory,
      ),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    final searchController = TextEditingController();
    final sidebarScrollController = ScrollController();
    var savedOffset = 0.0;
    addTearDown(searchController.dispose);
    addTearDown(sidebarScrollController.dispose);

    Widget buildSidebar() {
      return ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildTheme(
            paletteFor(AppThemeMode.classicDark),
            brightness: Brightness.dark,
            appFontPreset: AppFontPreset.inter,
            chatFontPreset: AppFontPreset.inter,
          ),
          home: Scaffold(
            body: SidebarDrawer(
              compact: true,
              searchController: searchController,
              scrollController: sidebarScrollController,
              initialScrollOffset: savedOffset,
              onScrollOffsetChanged: (offset) => savedOffset = offset,
              onSearchChanged: () {},
              onNewChat: () {},
              onSelectChat: (_) {},
              onSelectHome: () {},
              onSelectSettings: () {},
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildSidebar());
    await tester.pumpAndSettle();

    sidebarScrollController.jumpTo(220);
    await tester.pumpAndSettle();
    savedOffset = sidebarScrollController.offset;

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await tester.pumpWidget(buildSidebar());
    await tester.pumpAndSettle();

    expect(savedOffset, greaterThan(0));
    expect(sidebarScrollController.offset, closeTo(savedOffset, 0.01));
  });
}

class _BottomPromptBarHarness extends StatefulWidget {
  const _BottomPromptBarHarness();

  @override
  State<_BottomPromptBarHarness> createState() =>
      _BottomPromptBarHarnessState();
}

class _BottomPromptBarHarnessState extends State<_BottomPromptBarHarness> {
  final TextEditingController _controller = TextEditingController();
  bool _expanded = false;
  bool _generateImage = false;
  bool _generateDocument = false;
  bool _webSearch = false;
  bool _deepResearch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomPromptBar(
      controller: _controller,
      onSubmit: () async {},
      isStreaming: false,
      onStop: () async {},
      onImageTap: () async {},
      onCameraTap: () async {},
      onFileTap: () async {},
      onAttachTap: () {},
      onCommandsTap: () {},
      onModelTap: () {},
      onProviderTap: () {},
      onToggleOptions: () => setState(() => _expanded = !_expanded),
      showExpandedOptions: _expanded,
      selectedModelLabel: 'Gemini 2.5 Flash',
      selectedProviderLabel: 'All Providers',
      attachments: const [],
      onRemoveAttachment: (_) {},
      generateImageEnabled: _generateImage,
      generateDocumentEnabled: _generateDocument,
      webSearchEnabled: _webSearch,
      deepResearchEnabled: _deepResearch,
      isEditingLastMessage: false,
      activeModes: [
        if (_generateImage) 'Generate Image',
        if (_generateDocument) 'Generate Document',
        if (_webSearch) 'Web Search',
        if (_deepResearch) 'Deep Research',
      ],
      onToggleGenerateImage: () =>
          setState(() => _generateImage = !_generateImage),
      onToggleGenerateDocument: () =>
          setState(() => _generateDocument = !_generateDocument),
      onToggleWebSearch: () => setState(() => _webSearch = !_webSearch),
      onToggleDeepResearch: () =>
          setState(() => _deepResearch = !_deepResearch),
      showCommands: false,
      onSelectCommand: (_) {},
    );
  }
}

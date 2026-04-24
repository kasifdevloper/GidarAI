import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/core/models/app_models.dart';
import 'package:gidar_ai_flutter/src/presentation/workspace/workspace_overlays.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildChatSessionPdfBytes generates a shareable pdf document', () async {
    final session = ChatSession(
      id: 'session-1',
      title: 'Exported Chat हिंदी',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'Hello there नमस्ते',
          createdAt: DateTime(2026, 1, 1),
        ),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: 'Hi, how can I help? मैं मदद कर सकता हूँ।',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final bytes = await buildChatSessionPdfBytes(
      session: session,
      modelName: 'Gemini 2.0 Flash',
    );

    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });

  test('buildChatSessionPdfBytes keeps hindi emoji and formulas stable',
      () async {
    final session = ChatSession(
      id: 'session-unicode',
      title: 'Unicode Export 😀',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'मुझे यह formula समझाओ 😀',
          createdAt: DateTime(2026, 1, 1),
        ),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: r'''
ज़रूर। यह relation देखो:

\[
\frac{a^2 + b^2}{c_1} \approx \sqrt{\alpha + \beta} \to \infty
\]

Inline bhi: $x_1 + x_2 = y^2$ and emoji 😀🔥
''',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final bytes = await buildChatSessionPdfBytes(
      session: session,
      modelName: 'Gemini 2.5 Flash',
    );

    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1200));
  });

  test('buildChatSessionPdfBytes handles long markdown code and tables',
      () async {
    final longCode = List.generate(
      120,
      (index) =>
          'final line$index = "${'x' * 120}"; // long generated export stress line',
    ).join('\n');
    final longParagraph = List.generate(
      80,
      (index) =>
          'This is a very long export paragraph section $index with markdown **bold** markers, inline `code`, and enough words to force soft wrapping in the generated PDF output.',
    ).join('\n\n');
    final session = ChatSession(
      id: 'session-rich',
      title: 'Rich Export Stress Test',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'Please export this heavy chat.',
          createdAt: DateTime(2026, 1, 1),
        ),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: '''
| Feature | Details |
| --- | --- |
| Export | Should not hang |
| Code | Should wrap safely |

$longParagraph

```dart
$longCode
```
''',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final bytes = await buildChatSessionPdfBytes(
      session: session,
      modelName: 'Groq qwen/qwen3-32b',
    );

    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1500));
  });

  test('buildChatSessionPdfBytes handles exported html preview cards',
      () async {
    final htmlBody = List.generate(
      45,
      (index) => '''
<section style="padding:18px;border-radius:18px;background:linear-gradient(135deg,#0f172a,#1d4ed8);color:white;margin:12px 0;">
  <h2>Card $index</h2>
  <p>This HTML block simulates a rich preview card with styled content, badges, buttons, and layout containers.</p>
  <div style="display:flex;gap:12px;flex-wrap:wrap;">
    <span style="padding:6px 10px;border-radius:999px;background:rgba(255,255,255,.14);">Primary</span>
    <span style="padding:6px 10px;border-radius:999px;background:rgba(255,255,255,.10);">Secondary</span>
  </div>
</section>
''',
    ).join('\n');

    final session = ChatSession(
      id: 'session-html',
      title: 'HTML Export Stress Test',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      messages: [
        ChatMessage(
          id: 'u1',
          role: 'user',
          content: 'Export the generated HTML card response.',
          createdAt: DateTime(2026, 1, 1),
        ),
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          content: '''
```html
<!DOCTYPE html>
<html>
  <head>
    <title>Fancy Preview</title>
    <style>
      body { font-family: Inter, sans-serif; background: #020617; }
    </style>
  </head>
  <body>
    $htmlBody
    <script>
      console.log('interactive bits should be simplified for export');
    </script>
  </body>
</html>
```
''',
          createdAt: DateTime(2026, 1, 1),
        ),
      ],
    );

    final bytes = await buildChatSessionPdfBytes(
      session: session,
      modelName: 'OpenRouter anthropic/claude-sonnet-4',
    );

    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(1600));
  });
}

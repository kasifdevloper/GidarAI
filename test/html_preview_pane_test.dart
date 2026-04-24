import 'package:flutter_test/flutter_test.dart';
import 'package:gidar_ai_flutter/src/presentation/components/code_utils.dart';
import 'package:gidar_ai_flutter/src/presentation/workspace/html_preview_pane.dart';

void main() {
  test('buildHtmlPreviewModel extracts body content from full document', () {
    const source = '''
<!DOCTYPE html>
<html>
  <head>
    <title>Demo</title>
    <style>p { color: red; }</style>
  </head>
  <body>
    <h1>Hello</h1>
    <p>World</p>
  </body>
</html>
''';

    final model = buildHtmlPreviewModel(source);

    expect(model.title, 'Demo');
    expect(model.hasRenderableContent, isTrue);
    expect(model.renderHtml, contains('<h1>Hello</h1>'));
    expect(model.renderHtml, contains('p { color: red; }'));
  });

  test('buildHtmlPreviewModel replaces unsupported interactive elements', () {
    const source = '''
<html>
  <body>
    <iframe src="https://example.com"></iframe>
  </body>
</html>
''';

    final model = buildHtmlPreviewModel(source);

    expect(model.removedInteractiveContent, isTrue);
    expect(model.hasRenderableContent, isTrue);
    expect(
      model.renderHtml,
      contains('This interactive section is available in browser view.'),
    );
  });

  test('prepareHtmlPreviewDocument wraps html fragments with a shell', () {
    const fragment = '<div>Hello</div>';

    final document = prepareHtmlPreviewDocument(fragment);

    expect(document, contains('<!DOCTYPE html>'));
    expect(document, contains('<body>'));
    expect(document, contains(fragment));
  });

  test('detectFileFromCodeBlock treats short html snippets as previewable files',
      () {
    const html = '''
<div class="card">
  <h1>Hello</h1>
  <p>World</p>
</div>
''';

    final file = detectFileFromCodeBlock(html, 'html');

    expect(file, isNotNull);
    expect(file!.language, 'html');
    expect(file.fileName, 'index.html');
  });

  test('detectFileFromCodeBlock treats dart snippets as files without preview',
      () {
    const dartCode = '''
import 'package:flutter/material.dart';

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) => const Placeholder();
}
''';

    final file = detectFileFromCodeBlock(dartCode, 'dart');

    expect(file, isNotNull);
    expect(file!.language, 'dart');
    expect(file.fileName, 'main.dart');
  });
}

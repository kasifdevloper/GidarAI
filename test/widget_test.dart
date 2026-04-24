import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gidar_ai_flutter/src/app/gidar_app.dart';
import 'package:gidar_ai_flutter/src/core/models/app_descriptors.dart';

void main() {
  test('formatAppVersionLabel keeps version and build aligned', () {
    expect(formatAppVersionLabel('2.0.0', '1'), 'v2.0.0+1');
    expect(formatAppVersionLabel('2.0.0', ''), 'v2.0.0');
  });

  testWidgets('app boots into Gidar AI shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GidarApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

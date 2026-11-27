import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/ui/widgets.dart';

void main() {
  test('every tool has its own logo file', () {
    for (final id in toolLogos) {
      expect(File('assets/apps/$id.png').existsSync(), isTrue, reason: id);
    }
  });

  testWidgets('a tool shows its logo; the figures on Home only its colours', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            AppIcon(id: 'slope', icon: Icons.show_chart),
            AppIcon(id: 'traverse', icon: Icons.apps, logo: false),
          ],
        ),
      ),
    );
    expect(find.byKey(const ValueKey('logo slope')), findsOneWidget);
    expect(find.byKey(const ValueKey('logo traverse')), findsNothing);
    expect(find.byIcon(Icons.apps), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/ui/theme.dart';
import 'package:survey_toolkit/src/workspace/workspace_shell.dart';

import 'fakes.dart';

void main() {
  Future<(Harness, List<String>)> open(WidgetTester t, {required bool warmUp}) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = Harness(site: FakeSite(), store: signedInStore());
    final opened = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: WorkspaceShell(
          account: h.account,
          model: h.model,
          settings: h.settings,
          views: (app, start) {
            opened.add(app.id);
            return FakeView(app, start);
          },
          warmUp: warmUp,
        ),
      ),
    );
    await settle(t);
    return (h, opened);
  }

  testWidgets('Excel to KML starts loading behind Home a moment after the Toolkit opens', (t) async {
    final (_, opened) = await open(t, warmUp: true);
    // settle() waits 2 s: the moment has passed
    expect(opened, ['excel-to-kml']);
    // Home is still the page shown
    expect(find.text('Your tools'), findsOneWidget);
    // picked: the window already made is shown, not a second one
    await t.tap(find.byKey(const ValueKey('workspace Excel to KML')));
    await settle(t);
    expect(opened, ['excel-to-kml']);
  });

  testWidgets('without warm-up nothing opens until an app is picked', (t) async {
    final (_, opened) = await open(t, warmUp: false);
    await t.pump(const Duration(seconds: 3));
    expect(opened, isEmpty);
  });
}

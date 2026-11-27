// The real Auto Drafting, as the Toolkit shows it (not a stand-in): it opens, with its own files
// found inside the Toolkit, and asks for a sign-in when there is no account to borrow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_toolkit/src/workspace/apps.dart';
import 'package:survey_toolkit/src/workspace/workspace_shell.dart';

void main() {
  testWidgets('Auto Drafting opens inside the Toolkit', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1360, 860);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final app = workspaceApps.firstWhere((a) => a.id == 'auto-draft');
    await t.pumpWidget(MaterialApp(home: Scaffold(body: nativeView(app, null))));
    await t.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^Your (SurveyX Digital|Excel to KML) account$')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

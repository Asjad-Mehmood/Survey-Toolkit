import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/brand.dart';
import 'package:survey_toolkit/src/support/app_info.dart';
import 'package:survey_toolkit/src/support/crash_log.dart';

import 'fakes.dart';

void main() {
  tearDown(() => CrashLog.last.value = null);

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(Harness(site: FakeSite(), store: signedInStore()).app);
    await settle(t);
  }

  testWidgets('Help in the sidebar and on F1: what is new, guide, shortcuts, report, licences', (t) async {
    await open(t);
    await t.tap(find.text('Help'));
    await t.pumpAndSettle();
    expect(find.text('Version $appVersion · SurveyX Digital'), findsOneWidget);
    for (final s in ["What's new", 'User guide', 'Keyboard shortcuts', 'Report a problem', 'Open-source licences']) {
      expect(find.text(s), findsOneWidget);
    }
    await t.tap(find.text('Keyboard shortcuts'));
    await t.pumpAndSettle();
    expect(find.text('Ctrl+,'), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();

    await t.sendKeyEvent(LogicalKeyboardKey.f1);
    await t.pumpAndSettle();
    await t.tap(find.text('Open-source licences'));
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  test('Report a problem: the contact form with the Toolkit and its version', () {
    final u = Uri.parse(appInfo.reportUrl);
    expect(u.path, '/contact');
    expect(u.queryParameters, containsPair('program', 'toolkit'));
    expect(u.queryParameters, containsPair('version', appVersion));
  });

  testWidgets('an error shows a notice with Report a problem', (t) async {
    await open(t);
    CrashLog.record(StateError('the tools list could not be read'), StackTrace.current);
    await t.pump();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('crash notice')), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('crash notice')), findsNothing);
  });
}

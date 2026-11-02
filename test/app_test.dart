// The Toolkit against a fake exceltokml.com: sign in first, the beta list, the Tools page, what
// it reports to the website, offline, and every screen at phone to large-desktop sizes with large
// text, light and dark, without anything running off the edge.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:survey_toolkit/src/state/store.dart';

import 'fakes.dart';

void main() {
  testWidgets('signed out: the sign-in comes first; a wrong password says so; the right one opens the Tools page', (
    t,
  ) async {
    final h = Harness(site: FakeSite(), store: Store.memory());
    await t.pumpWidget(h.app);
    await settle(t);
    expect(find.text('Your Excel to KML account'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('beta test'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Email'), 'tester@example.com');
    await t.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(t);
    expect(find.text('Wrong email or password.'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'Password'), 'right');
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
    await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await settle(t);
    expect(find.text('Survey Toolkit'), findsOneWidget);
    expect(find.text('Excel to KML'), findsOneWidget);
  });

  testWidgets('not on the beta list: the closed message, Sign out and Check again; nothing reported', (t) async {
    final site = FakeSite()..tester = false;
    final h = Harness(
      site: site,
      store: signedInStore(beta: 'unknown'),
    );
    await t.pumpWidget(h.app);
    await settle(t);
    expect(find.textContaining('beta is closed'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(site.reports, isEmpty);

    // an admin adds the account, the user presses Check again
    site.tester = true;
    await t.tap(find.text('Check again'));
    await settle(t);
    expect(find.text('Excel to KML'), findsOneWidget);
  });

  testWidgets('the Tools page: each tool\'s status, versions and buttons; the PC is reported', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final site = FakeSite();
    final h = Harness(site: site, store: signedInStore());
    await t.pumpWidget(h.app);
    await settle(t);

    expect(find.text('1 update available'), findsOneWidget);
    expect(find.textContaining('2 of 5 installed'), findsOneWidget);
    expect(find.text('Installed 4.3.1 → latest 4.4.0'), findsOneWidget);
    expect(find.text('UPDATE AVAILABLE'), findsOneWidget);
    expect(find.text('Installed 1.0.3, the latest'), findsOneWidget);
    expect(find.text('UP TO DATE'), findsOneWidget);
    expect(find.text('NEEDS AUTOCAD'), findsOneWidget);
    expect(find.text('NOT INSTALLED'), findsNWidgets(2));
    expect(find.text('Get the update'), findsOneWidget);
    expect(find.text('Get it'), findsNWidgets(3));
    expect(find.text('Open'), findsNWidgets(2));
    expect(find.text('Web app'), findsNWidgets(2));
    expect(find.text('Already have it? Choose its folder'), findsOneWidget);
    // the website's note on Slope Calculator is for the owner: its download is fine, so not shown
    expect(find.textContaining('latest.json is missing'), findsNothing);
    expect(find.textContaining('look only'), findsOneWidget);

    // what the website was told: this PC and its installed versions
    expect(site.reports, isNotEmpty);
    final device = site.reports.last['device']! as Map;
    expect(device['id'], matches(RegExp(r'^pc-[0-9a-f]{24}$')));
    expect(device['tools'], {
      'excel-to-kml': '4.3.1',
      'roadpro': '',
      'traverse': '',
      'folder-manager': '',
      'slope': '1.0.3',
    });
    // the same id next time
    expect(h.model.deviceId, device['id']);
  });

  testWidgets('a tool whose download the website can\'t check says why', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final site = FakeSite();
    final j = jsonDecode(site.feed) as Map<String, Object?>;
    final traverse = (j['tools']! as List)[2] as Map<String, Object?>;
    traverse['download'] = null;
    traverse['problems'] = ["The latest release can't be read just now."];
    site.feed = jsonEncode(j);
    final h = Harness(site: site, store: signedInStore());
    await t.pumpWidget(h.app);
    await settle(t);
    expect(find.text("The latest release can't be read just now."), findsOneWidget);
  });

  testWidgets('offline: opens with the remembered sign-in and the tool list from the last check', (t) async {
    final store = signedInStore();
    final site = FakeSite();
    var h = Harness(site: site, store: store);
    await h.model.refresh(); // an earlier check, online
    expect(h.model.noFeed, isFalse);

    site.online = false;
    h = Harness(site: site, store: store);
    await t.pumpWidget(h.app);
    await settle(t);
    expect(find.text('1 update available'), findsOneWidget);
    expect(find.textContaining('(offline)'), findsOneWidget);
    expect(find.textContaining('No connection to exceltokml.com'), findsOneWidget);
  });

  testWidgets('a sign-in the website no longer accepts goes back to the sign-in', (t) async {
    final site = FakeSite()..tokenGood = false;
    final h = Harness(site: site, store: signedInStore());
    await t.pumpWidget(h.app);
    await settle(t);
    expect(find.text('Your Excel to KML account'.toUpperCase()), findsOneWidget);
  });

  group('every screen fits', () {
    const sizes = [Size(360, 640), Size(800, 600), Size(1024, 700), Size(1366, 768), Size(1920, 1080)];
    const scales = [1.0, 1.5, 2.0];
    for (final size in sizes) {
      for (final scale in scales) {
        for (final dark in [false, true]) {
          final name =
              '${size.width.toInt()}×${size.height.toInt()} text ${(scale * 100).round()} % ${dark ? 'dark' : 'light'}';
          testWidgets(name, (t) async {
            t.view.physicalSize = size;
            t.view.devicePixelRatio = 1;
            t.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(t.view.reset);
            addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
            final errors = <FlutterErrorDetails>[];
            final old = FlutterError.onError;
            FlutterError.onError = errors.add;
            addTearDown(() => FlutterError.onError = old);

            for (final store in [Store.memory(), signedInStore(beta: 'unknown'), signedInStore()]) {
              final site = FakeSite()..tester = store.readJson('account')?['beta'] != 'unknown';
              final h = Harness(site: site, store: store);
              h.settings.themeMode = dark ? ThemeMode.dark : ThemeMode.light;
              await t.pumpWidget(h.app);
              await settle(t);
              // scroll to the end
              final list = find.byType(Scrollable);
              if (list.evaluate().isNotEmpty) {
                await t.drag(list.first, const Offset(0, -6000));
                await settle(t);
              }
            }
            FlutterError.onError = old;
            expect(errors.map((e) => e.exceptionAsString()).where((m) => m.contains('overflowed')).toList(), isEmpty);
          });
        }
      }
    }
  });
}

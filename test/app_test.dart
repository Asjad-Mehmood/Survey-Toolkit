// The Toolkit against a fake exceltokml.com: sign in first, the beta list, the Tools page, what
// it reports to the website, offline, and every screen at phone to large-desktop sizes with large
// text, light and dark, without anything running off the edge.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:survey_toolkit/src/account/account.dart';
import 'package:survey_toolkit/src/account/api.dart';
import 'package:survey_toolkit/src/state/store.dart';
import 'package:survey_toolkit/src/toolkit/installer.dart';
import 'package:survey_toolkit/src/workspace/apps.dart';
import 'package:survey_toolkit/src/workspace/workspace_shell.dart';

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
    expect(find.text('1 update available'), findsOneWidget);
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
    expect(find.text('1 update available'), findsOneWidget);
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
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Install'), findsNWidgets(3));
    expect(find.text('Uninstall'), findsNWidgets(2));
    expect(find.text('Open'), findsNWidgets(2));
    expect(find.text('Web app'), findsNWidgets(2));
    expect(find.text('Already have it? Choose its folder'), findsOneWidget);
    // the website's note on Slope Calculator is for the owner: its download is fine, so not shown
    expect(find.textContaining('latest.json is missing'), findsNothing);
    expect(find.textContaining('checked by its SHA-256'), findsOneWidget);

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

  testWidgets('look only (no installer): Get it and Get the update open the browser instead', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = Harness(site: FakeSite(), store: signedInStore(), lookOnly: true);
    await t.pumpWidget(h.app);
    await settle(t);
    expect(find.text('Get the update'), findsOneWidget);
    expect(find.text('Get it'), findsNWidgets(3));
    expect(find.text('Uninstall'), findsNothing);
    expect(find.textContaining('look only'), findsOneWidget);
  });

  testWidgets('Update: the progress on the card, then the result; the website is told', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final site = FakeSite();
    final installer = FakeInstaller()
      ..gate = Completer<void>()
      ..next = const JobResult.done('Excel to KML is updated to 4.4.0.', version: '4.4.0');
    final h = Harness(site: site, store: signedInStore(), installer: installer);
    await t.pumpWidget(h.app);
    await settle(t);
    site.reports.clear();

    await t.tap(find.text('Update'));
    await t.pump();
    expect(installer.calls, ['install excel-to-kml']);
    expect(find.text('Downloading… 42 %'), findsOneWidget);
    // one job at a time: the other tools' Install buttons wait
    final installs = t.widgetList<ButtonStyleButton>(
      find.ancestor(of: find.text('Install'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    );
    expect(installs.every((b) => b.onPressed == null), isTrue);
    final uninstalls = t.widgetList<ButtonStyleButton>(
      find.ancestor(of: find.text('Uninstall'), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    );
    expect(uninstalls, isNotEmpty);
    expect(uninstalls.every((b) => b.onPressed == null), isTrue);

    installer.gate!.complete();
    await settle(t);
    expect(find.text('Excel to KML is updated to 4.4.0.'), findsOneWidget);
    final events = site.reports.expand((r) => (r['events']! as List).cast<Map<String, Object?>>()).toList();
    expect(events, [
      {'tool': 'excel-to-kml', 'action': 'updated', 'from': '4.3.1', 'to': '4.4.0'},
    ]);
  });

  testWidgets('a tool that is open: asked to close it, nothing reported', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final site = FakeSite();
    final installer = FakeInstaller()
      ..next = const JobResult.blocked('Close Excel to KML first, then press Update again.');
    final h = Harness(site: site, store: signedInStore(), installer: installer);
    await t.pumpWidget(h.app);
    await settle(t);
    site.reports.clear();
    await t.tap(find.text('Update'));
    await settle(t);
    expect(find.text('Close Excel to KML first, then press Update again.'), findsOneWidget);
    expect(site.reports.expand((r) => r['events']! as List), isEmpty);
  });

  testWidgets('a failed install is shown and reported with its reason', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final site = FakeSite();
    final installer = FakeInstaller()
      ..next = const JobResult.failed('The download didn\'t match its SHA-256 checksum.');
    final h = Harness(site: site, store: signedInStore(), installer: installer);
    await t.pumpWidget(h.app);
    await settle(t);
    site.reports.clear();
    await t.tap(find.text('Install').first);
    await settle(t);
    expect(find.text('The download didn\'t match its SHA-256 checksum.'), findsOneWidget);
    final events = site.reports.expand((r) => (r['events']! as List).cast<Map<String, Object?>>()).toList();
    expect(events.single['action'], 'failed');
    expect(events.single['tool'], 'roadpro');
    expect(events.single['message'], contains('SHA-256'));
  });

  testWidgets('Uninstall asks first; Cancel does nothing, Uninstall removes and reports', (t) async {
    t.view.physicalSize = const Size(1280, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final site = FakeSite();
    final installer = FakeInstaller()..next = const JobResult.done('Slope Calculator is removed.');
    final h = Harness(site: site, store: signedInStore(), installer: installer);
    await t.pumpWidget(h.app);
    await settle(t);
    site.reports.clear();

    await t.ensureVisible(find.text('Uninstall').last);
    await t.tap(find.text('Uninstall').last);
    await settle(t);
    expect(find.text('Uninstall Slope Calculator?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(installer.calls, isEmpty);

    await t.ensureVisible(find.text('Uninstall').last);
    await t.tap(find.text('Uninstall').last);
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Uninstall'));
    await settle(t);
    expect(installer.calls, ['uninstall slope']);
    expect(find.text('Slope Calculator is removed.'), findsOneWidget);
    final events = site.reports.expand((r) => (r['events']! as List).cast<Map<String, Object?>>()).toList();
    expect(events.single, {'tool': 'slope', 'action': 'uninstalled', 'from': '1.0.3'});
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

  group('the workspace', () {
    Future<Harness> open(WidgetTester t, {FakeSite? site, Store? store, Size size = const Size(1280, 900)}) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final h = Harness(site: site ?? FakeSite(), store: store ?? signedInStore());
      await t.pumpWidget(h.app);
      await settle(t);
      return h;
    }

    testWidgets('a sidebar with Home and the three web apps; RoadPro and Folder Manager stay on Home', (t) async {
      await open(t);
      for (final label in ['Home', 'Excel to KML', 'Traverse', 'Slope']) {
        expect(find.byKey(ValueKey('workspace $label')), findsOneWidget, reason: label);
      }
      expect(find.byKey(const ValueKey('workspace RoadPro')), findsNothing);
      expect(find.byKey(const ValueKey('workspace Project Folder Manager')), findsNothing);
      expect(find.text('1 update available'), findsOneWidget, reason: 'Home is the Tools page');
    });

    testWidgets('an app opens inside, signed in by a single-use handover, and stays open when switching', (t) async {
      final site = FakeSite();
      final h = await open(t, site: site);
      await t.tap(find.byKey(const ValueKey('workspace Slope')));
      await settle(t);
      expect(site.handoffs, ['/slope-calculation/app']);
      expect(find.text('Showing https://www.exceltokml.com/api/toolkit/handoff?code=${'c' * 64}'), findsOneWidget);
      expect(find.text('Slope Calculator'), findsWidgets);
      // installed on this PC: the Windows program is a click away
      expect(find.text('Windows app'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('workspace Home')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('workspace Slope')));
      await settle(t);
      expect(h.views, hasLength(1), reason: 'the same window, still open');
      expect(site.handoffs, hasLength(1));
    });

    testWidgets('no handover (offline, or the website refuses): the app opens with its own sign-in', (t) async {
      final site = FakeSite()..handoffWorks = false;
      await open(t, site: site);
      await t.tap(find.byKey(const ValueKey('workspace Traverse')));
      await settle(t);
      expect(find.text('Showing https://www.exceltokml.com/traverse/app'), findsOneWidget);
      // not installed here: no Windows app button
      expect(find.text('Windows app'), findsNothing);
    });

    testWidgets('the app grid, like Google\'s, jumps to any app', (t) async {
      await open(t);
      await t.tap(find.byTooltip('Switch app'));
      await settle(t);
      for (final name in ['Home', 'Excel to KML', 'Traverse & Level', 'Slope Calculator']) {
        expect(find.byKey(ValueKey('grid $name')), findsOneWidget, reason: name);
      }
      await t.tap(find.byKey(const ValueKey('grid Traverse & Level')));
      await settle(t);
      expect(find.textContaining('Showing https://www.exceltokml.com/api/toolkit/handoff'), findsOneWidget);
      expect(find.text('Traverse & Level'), findsWidgets);
    });

    testWidgets('Ctrl+1 to Ctrl+4', (t) async {
      final h = await open(t);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.digit2);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(t);
      expect(h.views.single.app.id, 'excel-to-kml');
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.digit1);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(t);
      expect(find.text('1 update available'), findsOneWidget);
    });

    testWidgets('opens where the user was last time', (t) async {
      final store = signedInStore();
      var h = await open(t, store: store);
      await t.tap(find.byKey(const ValueKey('workspace Slope')));
      await settle(t);
      await t.pumpWidget(const SizedBox());
      h = await open(t, store: store);
      expect(h.views.single.app.id, 'slope');
    });

    testWidgets('signing out makes every open app window forget its sign-in', (t) async {
      final h = await open(t);
      await t.tap(find.byKey(const ValueKey('workspace Slope')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('workspace Excel to KML')));
      await settle(t);
      await h.account.signOut();
      await settle(t);
      expect(find.text('Your Excel to KML account'.toUpperCase()), findsOneWidget);
      expect(h.views.every((v) => v.forgot), isTrue);
    });

    testWidgets('the preview for the Windows test: one app, no sign-in, nothing else reachable', (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final opened = <String>[];
      await t.pumpWidget(
        WorkspacePreview(
          appId: 'slope',
          views: (app, start) {
            opened.add(app.id);
            return FakeView(app, start);
          },
        ),
      );
      await settle(t);
      expect(opened, ['slope']);
      expect(find.text('Showing https://www.exceltokml.com/slope-calculation/app'), findsOneWidget);
      expect(find.text('1 update available'), findsNothing);
      await t.tap(find.byKey(const ValueKey('workspace Home')));
      await settle(t);
      expect(find.text('1 update available'), findsNothing);
    });

    test('pages off the website open in the browser', () {
      expect(staysInside(Uri.parse('https://www.exceltokml.com/slope-calculation/app')), isTrue);
      expect(staysInside(Uri.parse('https://accounts.google.com/x')), isFalse);
      expect(staysInside(Uri.parse('http://www.exceltokml.com/app')), isFalse);
    });

    test('a handover address from anywhere but the website is not used', () async {
      final site = FakeSite();
      final store = signedInStore();
      final account = Account(Api(base: 'https://www.exceltokml.com', client: site.client), store);
      expect(await account.handoffUrl('/app'), startsWith('https://www.exceltokml.com/api/toolkit/handoff?code='));
      final evil = Account(
        Api(
          base: 'https://www.exceltokml.com',
          client: MockClient(
            (_) async => http.Response(jsonEncode({'url': 'https://evil.example/api/toolkit/handoff'}), 200),
          ),
        ),
        store,
      );
      expect(await evil.handoffUrl('/app'), isNull);
    });
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

            final withApp = signedInStore()..write('workspace-last', 'slope');
            for (final store in [Store.memory(), signedInStore(beta: 'unknown'), signedInStore(), withApp]) {
              final site = FakeSite()..tester = store.readJson('account')?['beta'] != 'unknown';
              final h = Harness(site: site, store: store);
              h.settings.themeMode = dark ? ThemeMode.dark : ThemeMode.light;
              await t.pumpWidget(h.app);
              await settle(t);
              // scroll to the end
              final lists = find.byType(Scrollable);
              for (var i = 0; i < lists.evaluate().length; i++) {
                await t.drag(lists.at(i), const Offset(0, -6000), warnIfMissed: false);
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

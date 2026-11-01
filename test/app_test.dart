// The Toolkit against a fake exceltokml.com: sign in first, the beta list, the Tools page, what
// it reports to the website, offline, and every screen at phone to large-desktop sizes with large
// text, light and dark, without anything running off the edge.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:survey_toolkit/src/account/account.dart';
import 'package:survey_toolkit/src/account/api.dart';
import 'package:survey_toolkit/src/app.dart';
import 'package:survey_toolkit/src/state/store.dart';
import 'package:survey_toolkit/src/toolkit/detect.dart';
import 'package:survey_toolkit/src/toolkit/feed.dart';
import 'package:survey_toolkit/src/toolkit/toolkit_model.dart';
import 'package:survey_toolkit/src/ui/settings.dart';

/// A fake exceltokml.com
class FakeSite {
  bool online = true;
  bool tester = true;
  bool tokenGood = true;
  final reports = <Map<String, Object?>>[];
  final feed = File('test/fixtures/feed.json').readAsStringSync();

  late final client = MockClient((req) async {
    if (!online) throw http.ClientException('offline');
    final path = req.url.path;
    final authed = req.headers['Authorization'] == 'Bearer tok' && tokenGood;
    http.Response json(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    switch (path) {
      case '/api/auth/me':
        return authed ? json({'user': _user}) : json({'error': 'Sign in'}, 401);
      case '/api/auth/login':
        final b = jsonDecode(req.body) as Map;
        return b['password'] == 'right'
            ? json({'user': _user, 'token': 'tok'})
            : json({'error': 'Wrong email or password.'}, 401);
      case '/api/toolkit/me':
        if (!authed) return json({'error': 'Sign in'}, 401);
        return json({
          'success': true,
          'tester': tester,
          'admin': false,
          if (!tester) 'message': 'The Survey Toolkit beta is closed. It opens to everyone when the test is over.',
        });
      case '/api/toolkit/feed':
        return http.Response(feed, 200, headers: {'content-type': 'application/json'});
      case '/api/toolkit/event':
        if (!authed) return json({'error': 'Sign in'}, 401);
        reports.add(jsonDecode(req.body) as Map<String, Object?>);
        return json({'success': true});
      case '/api/auth/logout':
        return json({'success': true});
    }
    return json({'error': 'not found'}, 404);
  });

  static const _user = {'id': 'u1', 'email': 'tester@example.com', 'name': 'Test Surveyor'};
}

class FakeDetector implements Detector {
  FakeDetector(this.found, {this.autocad = true});
  final Map<String, Installed> found;
  final bool autocad;
  @override
  Future<Installed> find(FeedTool tool) async => found[tool.id] ?? Installed.none;
  @override
  Future<bool> hasAutocad() async => autocad;
}

/// Excel to KML one version behind, Slope Calculator up to date with a program to open, the
/// others not installed, no AutoCAD
FakeDetector typicalPc() => FakeDetector({
  'excel-to-kml': const Installed(version: '4.3.1', folder: r'C:\X', program: r'C:\X\ExcelToKML.exe'),
  'slope': const Installed(version: '1.0.3', folder: r'C:\S', program: r'C:\S\SlopeCalculator.exe'),
}, autocad: false);

class Harness {
  Harness({required this.site, required this.store, Detector? detector}) {
    account = Account(Api(base: 'https://www.exceltokml.com', client: site.client), store);
    model = ToolkitModel(account: account, store: store, detector: detector ?? typicalPc());
    settings = AppSettings(store);
  }
  final FakeSite site;
  final Store store;
  late final Account account;
  late final ToolkitModel model;
  late final AppSettings settings;

  Widget get app => ToolkitApp(account: account, model: model, settings: settings);
}

/// A store as if this account signed in on this PC before
Store signedInStore({String beta = 'tester'}) {
  final s = Store.memory();
  s.writeJson('account', {'token': 'tok', 'user': FakeSite._user, 'beta': beta});
  return s;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

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
    expect(find.textContaining('latest.json is missing'), findsOneWidget);
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
